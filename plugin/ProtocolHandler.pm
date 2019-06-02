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
	my $streamUrl = $song->streamUrl() || return;

	main::DEBUGLOG && $log->is_debug && $log->debug( 'Remote streaming TVH track: ' . $streamUrl );

	my $mime = $song->pluginData('mime');

	my $sock = $class->SUPER::new( {
		url     => $streamUrl,
		song    => $song,
		client  => $client,
#		bitrate => $mime =~ /flac/i ? 750_000 : MP3_BITRATE,
	} ) || return;

	${*$sock}{contentType} = $mime;

	return $sock;
}

sub scanUrl {
	my ($class, $url, $args) = @_;
	$args->{cb}->( $args->{song}->currentTrack() );
}

sub isRemote { 1 }

sub isAudioURL { 1 }

sub canDirectStreamSong {
	my ( $class, $client, $song ) = @_;

	# We need to check with the base class (HTTP) to see if we
	# are synced or if the user has set mp3StreamingMethod
	return $class->SUPER::canDirectStream( $client, $song->streamUrl() );
}

sub audioScrobblerSource { 'P' }

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

	my ($id) = $class->crackStreamUrl($url);
	$id ||= $url;

	my $epg;
	my $meta;

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

	$epg = (@$epg)[0];

	$meta = {
		title    => $epg->{channelName} . ' - ' . $epg->{title},
		
		# album    => $album->{title} || '',
		# albumId  => $album->{id},
		# artist   => $class->getArtistName($track, $album),
		# artistId => $album->{artist}->{id} || '',
		# composer => $track->{composer}->{name} || '',
		# composerId => $track->{composer}->{id} || '',
		# performers => $track->{performers} || '',
		# cover    => $album->{image}->{large} || '',
		# duration => $track->{duration} || 0,
		# year     => $album->{year} || (localtime($album->{released_at}))[5] + 1900 || 0,
		# goodies  => $album->{goodies},
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

sub getStreamUrl {
	my ($class, $id) = @_;

	return '' unless $id;

	return 'tvh://stream/' . $id;
}

sub crackStreamUrl {
	my ($class, $url) = @_;

	return unless $url;

	my ($id) = $url =~ m{^tvh://stream/([^\.]+)$};

    return Plugins::TVH::Prefs::getApiUrl() . 'stream/channelnumber/' . $id . Plugins::TVH::Prefs::getProfile();					
}

1;