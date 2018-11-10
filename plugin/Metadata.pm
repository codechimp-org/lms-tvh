package Plugins::TVH::Metadata;

use strict;

use Tie::Cache::LRU;

use Slim::Formats::RemoteMetadata;
use Slim::Utils::Cache;
use Slim::Utils::Log;

use Plugins::TVH::Plugin;

use constant ARTIST       => 'TVH';
use constant CACHE_PREFIX => 'TVH_meta';
use constant CACHE_TTL    => 30 * 86400;

my $log = logger('plugin.TVH');
my $cache = Slim::Utils::Cache->new();

# In-memory cache for the most often used tracks. Should cover a full show.
tie my %memCache, 'Tie::Cache::LRU', 50;

sub init {
	my $class = shift;

	Slim::Formats::RemoteMetadata->registerProvider(
		match => qr{https?://phish\.in/audio},
		func  => \&provider,
	);
}

sub provider {
	my ( $client, $url ) = @_;

	return __PACKAGE__->getMetadataFor($url);
}

sub getMetadataFor {
	my ( $class, $url ) = @_;

	# read from memory cache first, we're called often by the web UI
	my $meta = $memCache{$url};
	
	if (!$meta) {
		$meta = $cache->get(CACHE_PREFIX . $url);

		# if we found data in the cache, keep a copy in memory, too
		if ($meta) {
			$memCache{$url} = $meta;
		}
		else {
			$meta = {};
		}
	} 

	$meta->{cover} ||= Plugins::TVH::Plugin->_pluginDataFor('icon');

	main::DEBUGLOG && $log->is_debug && $log->debug("Found metadata for $url: " . Data::Dump::dump($meta));
	return $meta;
}

sub setMetadata {
	my ( $class, $track, $show ) = @_;

	if (!$track->{mp3}) {
		$log->warn("Metadata is missing audio stream URL? " . $track);
		main::INFOLOG && $log->is_info && $log->info(Data::Dump::dump($track));
		return;
	}

	# consider the show details the album information
	my $album = $show->{date} || '';
	if (my $venue = $show->{venue}) {
		$album = ($album ? "$album - " : '') . $venue->{name};

		if ($track->{set_name}) {
			$album .= ' (' . $track->{set_name} . ')';
		}
	}

	my $meta = {
		title => $track->{title},
		artist => ARTIST,
		album => $album,
		cover => Plugins::TVH::Plugin->_pluginDataFor('icon'),
		url   => $track->{mp3},
		tracknum => $track->{position},
		secs  => (delete $track->{duration}) / 1000,
	};

	$memCache{$meta->{url}} = $meta;

	$cache->set(CACHE_PREFIX . $meta->{url}, $meta);
	return $meta;
}

1;