package Plugins::TVH::Plugin;

use strict;

use base qw(Slim::Plugin::OPMLBased);

use Slim::Utils::Strings qw(string cstring);
use Slim::Utils::Log;
use Slim::Utils::Prefs;

use Plugins::TVH::API;
use Plugins::TVH::Metadata;

use Plugins::TVH::Settings;
use LWP::Simple;

my $prefs = preferences('plugin.TVH');

sub getApiUrl {
	return 'http://' . $prefs->get('username') . ':' . $prefs->get('password') . '@' . $prefs->get('server') . ':' . $prefs->get('port') . '/';	
}

sub getApiUrlNoAuth {
	return 'http://' . $prefs->get('server') . ':' . $prefs->get('port') . '/';
}

use vars qw($VERSION);

my $log = Slim::Utils::Log->addLogCategory( {
	category     => 'plugin.TVH',
	defaultLevel => 'WARN',
	description  => 'PLUGIN_TVH',
} );

sub initPlugin {
	my $class = shift;

	Plugins::TVH::Settings->new;

	$VERSION = $class->_pluginDataFor('version');

	Plugins::TVH::Metadata->init();

	# Slim::Menu::GlobalSearch->registerInfoProvider( tvh => (
	# 	func => sub {
	# 		my ( $client, $tags ) = @_;

	# 		my $searchParam = $tags->{search};
	# 		my $passthrough = [{ q => $searchParam }];

	# 		return {
	# 			name => cstring($client, 'PLUGIN_TVH'),
	# 			type => 'link',
	# 			# need to return a list of search items - might be a bug in GlobalSearch?
	# 			items => [{
	# 				url => sub {
	# 					warn Data::Dump::dump($_[1]);
	# 					search(@_);
	# 				},
	# 				passthrough => $passthrough,
	# 				searchParam => $searchParam,
	# 			}]
	# 		};
	# 	}
	# ) );

	$class->SUPER::initPlugin(
		feed   => \&handleFeed,
		tag    => 'TVH',
		menu   => 'radios',
		is_app => 1,
		weight => 1,
	);
}

sub getDisplayName { 'PLUGIN_TVH' }
sub playerMenu {}

sub handleFeed {
	my ($client, $cb, $args) = @_;

	if (!$client) {
		$cb->([{ name => cstring($client, 'NO_PLAYER_FOUND') }]);
		return;
	}

	# Validate that all settings have values
	if (!$prefs->get('server')||!$prefs->get('port')||!$prefs->get('username')||!$prefs->get('password')||!$prefs->get('tag')) {
		$cb->([{ name => cstring($client, 'PLUGIN_TVH_NO_SETTINGS') }]);
		return;
	}

	$client = $client->master;

	my $items = [
		{
			name => 'Test BBC 6 Music',
			type => 'audio',
			url  => getApiUrl() . 'stream/channelnumber/707',
		}
		,{
			name => cstring($client, 'PLUGIN_TVH_STATIONS'),
			type => 'link',
			url  => \&stations,
		},{
			name => cstring($client, 'PLUGIN_TVH_TAGS'),
			type => 'link',
			url  => \&tags,
		},{
			name => cstring($client, 'PLUGIN_TVH_RECORDINGS'),
			type => 'link',
			url  => \&recordings,
		}
	];

	$cb->({
		items => $items,
	});
}

sub tags {
	my ($client, $cb, $params) = @_;

	Plugins::TVH::API->getTags(sub {
		my ($tags) = @_;

		my $items = [];
		foreach (@$tags) {
			my ($tag) = $_;
			push $items, {
				name => $_->{val},
				url => \&taggedstations,
				passthrough => [{
					uuid => $_->{key}
				}],
			}
		}

		$cb->({ items => $items });
	});
}

sub taggedstations {
	my ($client, $cb, $params, $args) = @_;
	my $tagUuid = $params->{uuid} || $args->{uuid};

	Plugins::TVH::API->getStations(sub {
		my ($stations) = @_;

		my $items = _renderStations($stations, $tagUuid);

		$cb->({
			items => $items
		});
	});
}

sub recordings {
	my ($client, $cb, $params) = @_;

	Plugins::TVH::API->getRecordings(sub {
		my ($recordings) = @_;

		my $items = _renderRecordings($recordings);

		$cb->({ items => $items });
	});
}

sub stations {
	my ($client, $cb, $params, $args) = @_;

	Plugins::TVH::API->getStations(sub {
		my ($stations) = @_;
        
        #TODO: Change this to use tag guid based on lookup, see NotWorking version
        
		# Luke
		# my $items = _renderStations($stations, '235f7ae1a2f4bfc2f8871f65c18f6685');

		# Karpo
		my $items = _renderStations($stations, 'c981c251f22a82b09fdbc7edc85a338b');
		

		$cb->({
			items => $items
		});
	});
}

sub stationsNotWorking {
	my ($client, $cb, $params, $args) = @_;

	Plugins::TVH::API->getStationsNotWorking(sub {
		my ($stations) = @_;

		$log->error('TVH getStations called back');

		my $items = _renderStations($stations, '235f7ae1a2f4bfc2f8871f65c18f6685');

		$cb->({
			items => $items
		});
	});
}

sub _renderStations {
	my ($stations, $tag) = @_;

	my $items = [];

	foreach (@$stations) {
		
		my (@tags) = $_->{tags};
			
		if ($tags[0][0] == $tag) {
			push @$items, {
				name => $_->{name},
				line1 => $_->{name},
				line2 => $_->{number},
				type => 'audio',
				#image => getApiUrlNoAuth() . $_->{icon_public_url},  
				image => _getImage($_->{icon_public_url}),  
				url => getApiUrl() . 'stream/channelnumber/' . $_->{number}
			}
		}

	}

	return $items;
}

sub _renderRecordings {
	my ($recordings) = @_;

	my $items = [];

	foreach (@$recordings) {
		
		push @$items, {
			name => $_->{disp_title},
			line1 => $_->{disp_title},
			line2 => $_->{channelname},
			type => 'audio',
			image => getApiUrlNoAuth() . $_->{icon_public_url},
			url => getApiUrl() . $_->{url}
			}
	}

	return $items;
}

#This works, just need an image placeholder
sub _getImage {
	my $image = getApiUrlNoAuth() . "$_[0]";

#	$log->error('TVH getImage: (' . $image . ')');

	if (head("$image")) {
		return "$image";
	}
	else {
		return "noTVHImage.jpg";
	}

}

1;