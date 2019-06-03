package Plugins::TVH::ProtocolHandler;

use strict;
use base qw(Slim::Player::Protocols::HTTP);

use Slim::Utils::Cache;
use Slim::Utils::Log;
use Slim::Utils::Misc;
use Slim::Utils::Prefs;

use Plugins::TVH::Prefs;
use Plugins::TVH::API;

my $prefs = preferences('plugin.TVH');

my $log = logger('plugin.TVH');

sub new {
	my $class  = shift;
	my $args   = shift;

	my $client    = $args->{client};
	my $song      = $args->{song};
	my $streamUrl = crackUrl($song->streamUrl()) || return;

	my $self;

	main::DEBUGLOG && $log->is_debug && $log->debug( 'Remote streaming TVH track: ' . $streamUrl );

	my $mime = $song->pluginData('mime');

	$self = $class->SUPER::new( { 
		url     => $streamUrl,
		song    => $song,
		client  => $client,
		create  => 1,
	} );

	return $self;
}

sub scanUrl {
	my ($class, $url, $args) = @_;
	$args->{cb}->( $args->{song}->currentTrack() );
}

sub isRemote { 1 }

sub isAudioURL { 1 }

sub canDirectStreamSong {
	my ( $class, $client, $song ) = @_;

	main::DEBUGLOG && $log->is_debug && $log->debug( 'TVH track: ' . $song->streamUrl() );

	# We need to check with the base class (HTTP) to see if we
	# are synced or if the user has set mp3StreamingMethod
	return $class->SUPER::canDirectStream( $client, crackUrl($song->streamUrl()) );
}

sub audioScrobblerSource { 'R' }

sub canSeek { 0 }

sub getFormatForURL {
	my $classOrSelf = shift;
	my $url = shift;

	my $cache = Slim::Utils::Cache->new;
	my $meta  = $cache->get( $url );

	return $meta->{type};
}

sub getMetadataFor {
	my ( $class, $client, $url ) = @_;

	my ($id) = $class->crackUrl($url);
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
		icon    => 'http://192.168.3.142:9981/imagecache/51',
		cover    => 'http://192.168.3.142:9981/imagecache/51',
		
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

	my $id = crackUrl($url);
	my $image = Plugins::TVH::Prefs::getApiUrlNoAuth() . "$id";

	if (head("$image")) {
		return "$image";
	}
	else {
		return "plugins/TVH/html/images/radio.png";
	}
}

sub getUrl {
	my ($class, $id) = @_;

	return '' unless $id;

	return 'tvh://stream/' . $id;
}

sub crackUrl {
	my ($class, $url) = @_;

	return unless $url;

	my ($id) = $url =~ m{^tvh://stream/([^\.]+)$};

	$log->debug( 'Cracked Channel ID: ' . $id );

    return Plugins::TVH::Prefs::getApiUrl() . 'stream/channelnumber/' . $id . Plugins::TVH::Prefs::getProfile();					
}

1;