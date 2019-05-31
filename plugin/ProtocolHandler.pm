package Plugins::TVH::ProtocolHandler;

use strict;
use base qw(Slim::Player::Protocols::HTTP);

use Slim::Utils::Cache;
use Slim::Utils::Log;
use Slim::Utils::Misc;

use Plugins::TVH::Prefs;

my $log = logger('plugin.TVH');

sub new {
	my $class  = shift;
	my $args   = shift;

	my $client    = $args->{client};
	my $song      = $args->{song};
	my $streamUrl = $song->streamUrl() || return;

	my $cache = Slim::Utils::Cache->new;
	my $url   = $song->url();

        my $meta  = $cache->get( $url );

	my $sock = $class->SUPER::new( {
		url     => $streamUrl,
		song    => $args->{song},
		client  => $client,
		bitrate => $meta->{bitrate},
	} ) || return;

	${*$sock}{contentType} = $meta->{type};

	return $sock;
}

# Note: the following methods are NOT implemented:
# sub getNextSong {}
# sub canDirectStream {}
# sub canIndirectStream {}
# sub getSeekData {}
# sub onStreamingComplete {}
# sub trackinfo {}
# sub getCurrentTitle {}
# sub trackGain {}
# sub onStop {}
# sub onPlayout {}
# sub onStream {}
# sub overridePlayback {}

sub scanUrl {
	my ($class, $url, $args) = @_;
	$args->{'cb'}->($args->{'song'}->currentTrack());
}

sub isRemote { 1 }

sub isAudioURL { 1 }

sub canDirectStreamSong {
	my ( $class, $client, $song ) = @_;

	# We need to check with the base class (HTTP) to see if we
	# are synced or if the user has set mp3StreamingMethod
	return $class->SUPER::canDirectStream( $client, $song->streamUrl(), $class->getFormatForURL($song->track->url()) );
}

sub audioScrobblerSource { 'P' }

sub canSeek { 1 }

sub getFormatForURL {
	my $classOrSelf = shift;
	my $url = shift;

	my $cache = Slim::Utils::Cache->new;
	my $meta  = $cache->get( $url );

	return $meta->{type};
}

sub getMetadataFor {
	my ( $class, $client, $url ) = @_;

	my $cache = Slim::Utils::Cache->new;

    my $meta  = $cache->get( $url );


	return {

		artist   =>   $meta->{artist},
		album    =>   $meta->{album},
		title    =>   $meta->{title},
		cover    =>   $meta->{cover} || '',
		icon     =>   $meta->{icon} !! '',
		duration =>   $meta->{duration},
		bitrate  =>   $meta->{bitrate} ? int($meta->{bitrate} / 1000) . 'kbps' : '',
		type     => ( $meta->{type} ? ucfirst($meta->{type}) : '??' ) . ' (by Whitebear)',
		genre    =>   $meta->{genre},

	};
}

sub shouldLoop { 0 }

# sub getIcon {
# 	my ( $class, $url ) = @_;
#
#     my ($id) = $url =~ m{^tvh://stream/([^\.]+)$}
#
#     return Plugins::TVH::Plugin:getStationImage($station->{icon_public_url}),
# }

sub getUrl {
	my ($class, $id) = @_;

	return '' unless $id;

	return 'tvh://stream/' . $id;
}

sub crackUrl {
	my ($class, $url) = @_;

	return unless $url;

	my ($id) = $url =~ m{^tvh://stream/([^\.]+)$}

    return Plugins::TVH::Prefs::getApiUrl() . 'stream/channelnumber/' . $id . Plugins::TVH::Prefs::getProfile();					
}
1;