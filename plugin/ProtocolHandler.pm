package Plugins::TVH::ProtocolHandler;

use strict;
use base qw(Slim::Player::Protocols::HTTP);

use Slim::Utils::Cache;
use Slim::Utils::Log;
use Slim::Utils::Misc;
use Slim::Utils::Prefs;

use Plugins::TVH::Prefs;
use Plugins::TVH::API;

use LWP::Simple;
use Data::Dumper;

my $prefs = preferences('plugin.TVH');

my $log = logger('plugin.TVH');

sub new {
	my $class  = shift;
	my $args   = shift;

	my $client    = $args->{client};
	my $song      = $args->{song};
	my $realStreamUrl = getStreamURL($song->streamUrl()) || return;

	my $self;

	main::DEBUGLOG && $log->is_debug && $log->debug( 'Remote streaming TVH track: ' . $realStreamUrl );


#[19-06-07 10:30:33.5203] Slim::Player::Song::open (472) Warning: stream failed to open [tvh://stream?channelnumber=707&uuid=8fb706196a53dec66fd3f5178c492154&icon=imagecache/17].

	my $mime = $song->pluginData('mime');

	my $sock = $class->SUPER::new( { 
		url     => $realStreamUrl,
		song    => $song,
		client  => $client,
		create  => 1,
	} );

	${*$sock}{contentType} = 'audio/aac';

	return $sock;
}

sub scanUrl {
	my ($class, $url, $args) = @_;
	$args->{cb}->( $args->{song}->currentTrack() );
}

sub isRemote { 1 }

sub canDirectStreamSong {
	my ( $class, $client, $song ) = @_;

	# main::DEBUGLOG && $log->is_debug && $log->debug( 'TVH track: ' . $song->streamUrl() );

	# # We need to check with the base class (HTTP) to see if we
	# # are synced or if the user has set mp3StreamingMethod
	# return $class->SUPER::canDirectStream( $client, getStreamURL($song->streamUrl()) );

	return 1;
}

sub audioScrobblerSource { 'R' }

sub canSeek { 0 }

# sub getFormatForURL {
# 	my $classOrSelf = shift;
# 	my $url = shift;

# 	my $cache = Slim::Utils::Cache->new;
# 	my $meta  = $cache->get( $url );

# 	return $meta->{type};
# }

sub getFormatForURL { 'aac' }

sub getMetadataFor {
	my ( $class, $client, $url ) = @_;

	my ($id) = $class->getUUID($url);
	$id ||= $url;

	$log->info('getMetaDataFor: ' . $url);

	my $epg;
	my $meta = {};

	# grab metadata from backend if needed, otherwise use cached values
	# if ($id && $client->master->pluginData('fetchingMeta')) {
	# 	Slim::Control::Request::notifyFromArray( $client, [ 'newmetadata' ] ) if $client;
	# 	$epg = Plugins::TVH::API->getCachedFileInfo($id);
	# }
	# elsif ($id) {
		$client->master->pluginData( fetchingMeta => 1 );

		$epg = Plugins::TVH::API->getEpg(sub {
			$client->master->pluginData( fetchingMeta => 0 );
		}, $id);
	# }

		Plugins::TVH::API->getEpg(sub {
				my ($epg) = @_;

				my $epgrow = (@$epg)[0];
				$log->info('EPG: ' . $epgrow->{title});
				
				# for my $epgrow (@$epg) {
				# 	$log->info('EPG: ' . $epgrow->{title});
				# }

			}, $id);

	# $epg = (@$epg)[0];

	 $meta = {
	# 	title    => $epg->{channelName} . ' - ' . $epg->{title},
		icon    => $class->getIcon($url),
		cover    => $class->getIcon($url),
		
	# 	# album    => $album->{title} || '',
	# 	# albumId  => $album->{id},
	# 	# artist   => $class->getArtistName($track, $album),
	# 	# artistId => $album->{artist}->{id} || '',
	# 	# composer => $track->{composer}->{name} || '',
	# 	# composerId => $track->{composer}->{id} || '',
	# 	# performers => $track->{performers} || '',
	# 	# cover    => $album->{image}->{large} || '',
	# 	# duration => $track->{duration} || 0,
	# 	# year     => $album->{year} || (localtime($album->{released_at}))[5] + 1900 || 0,
	# 	# goodies  => $album->{goodies},
	};

	return $meta;
}

sub shouldLoop { 0 }

# sub getIcon {
# 	my ( $class, $url ) = @_;
#
#     my ($id) = $url =~ m{^tvh://stream/([^\.]+)$}
#
#     return Plugins::TVH::Plugin:getStationImage($station->{icon_public_url}),
# }

sub getIcon {
	my ( $class, $url ) = @_;

	$log->info('getIcon: ' . $url);

	my $iconurl = getIconURL($url);
	my $image = Plugins::TVH::Prefs::getApiUrlNoAuth() . "$iconurl";

	if (head("$image")) {
		return "$image";
	}
	else {
		return "plugins/TVH/html/images/radio.png";
	}
}

sub getTVHUrl {
	my ($class, $station) = @_;
	return 'tvh://stream?channelnumber=' . $station->{number} . '&uuid=' . $station->{uuid} . '&icon=' . $station->{icon_public_url};
}

# sub crackUrl {
# 	my ($class, $url) = @_;
# 	return unless $url;

# 	my ($channelnumber) = $url =~ m{^tvh://stream\?channelnumber=([^\.]+)\&};
# 	my ($uuid) = $url =~ m{\&uuid=(.*)$};

# 	$log->debug( 'Cracked URL: ' . $channelnumber . ':' . $uuid );

#     return Plugins::TVH::Prefs::getApiUrl() . 'stream/channelnumber/' . $channelnumber . Plugins::TVH::Prefs::getProfile();					
# }

sub getStreamURL {
	my ($class, $url) = @_;
	return unless $url;

	my ($channelnumber) = $url =~ m{^tvh://stream\?channelnumber=([^\.]+)\&};
    return Plugins::TVH::Prefs::getApiUrl() . 'stream/channelnumber/' . $channelnumber . Plugins::TVH::Prefs::getProfile();					
}

sub getUUID {
	my ($class, $url) = @_;
	return unless $url;

	my ($uuid) = $url =~ m{\&uuid=(.*)\&};
    return $uuid;					
}

sub getIconURL {
	my ($class, $url) = @_;
	return unless $url;

	my ($uuid) = $url =~ m{\&icon=(.*)$};
    return $uuid;					
}

1;