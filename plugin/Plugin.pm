package Plugins::TVH::Plugin;

#use strict;

use base qw(Slim::Plugin::OPMLBased);

use Slim::Utils::Strings qw(string cstring);
use Slim::Utils::Log;
use Slim::Utils::Prefs;

use Plugins::TVH::API;
use Plugins::TVH::Metadata;

use Plugins::TVH::Settings;
use LWP::Simple;

use Data::Dumper;

my $prefs = preferences('plugin.TVH');

sub _getApiUrl {
	return 'http://' . $prefs->get('username') . ':' . $prefs->get('password') . '@' . $prefs->get('server') . ':' . $prefs->get('port') . '/';	
}

sub _getApiUrlNoAuth {
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

	# Default the preferences
	$prefs->init({
		port => '9981',
	});

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
	if (!$prefs->get('server')||!$prefs->get('port')||!$prefs->get('username')||!$prefs->get('password')) {
		$cb->([{ name => cstring($client, 'PLUGIN_TVH_NO_SETTINGS') }]);
		return;
	}

	$client = $client->master;

	my $items = [
		{
			name => cstring($client, 'PLUGIN_TVH_TAGS'),
			type => 'link',
			url  => \&tags,
			image => 'plugins/TVH/html/images/radiotower.png',
		},{
			name => cstring($client, 'PLUGIN_TVH_RECORDINGS'),
			type => 'link',
			url  => \&recordings,
			image => 'plugins/TVH/html/images/recording.png',
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
			push @$items, {
				name => $_->{val},
				url => \&getStationsByTag,
				passthrough => [{
					uuid => $_->{key}
				}],
			}
		}

		@$items = sort {$a->{name} cmp $b->{name}} @$items;

		$cb->({ items => $items });
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

sub getStationsByTag {
	my ($client, $cb, $params, $args) = @_;
	my $tagUuid = $params->{uuid} || $args->{uuid};
	$log->error(Data::Dump::dump($params));
	$log->error(Data::Dump::dump($args));
	Plugins::TVH::API->getStations(sub {
		my ($stations) = @_;

		my $items = _renderStations($stations, $tagUuid);

		@$items = sort {$a->{name} cmp $b->{name}} @$items;

		$cb->({
			items => $items
		});
	});
}

sub _renderStations {
	my ($stations, $tag) = @_;

	my $items = [];

	# $log->error('TVH - tag: ' . $tag);

	for my $station (@$stations) {
		my (@tags) = $station->{tags};

		# $log->error('TVH assessing channel: ' . $_->{name} . ' (' . $tags[0][0] . ')' );

		for my $row (@tags) {
			for my $element (@$row) { 
				# $log->error($element);
				if ($element eq $tag) {

					push @$items, {
						name => $station->{name},
						line1 => $station->{name},
						line2 => $station->{number},
						type => 'audio',
						image => _getStationImage($station->{icon_public_url}),  
						url => _getApiUrl() . 'stream/channelnumber/' . $station->{number}
					}
				}
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
			image => _getApiUrlNoAuth() . $_->{icon_public_url},
			url => _getApiUrl() . $_->{url}
			}
	}

	return $items;
}

sub _getStationImage {
	my $image = _getApiUrlNoAuth() . "$_[0]";

	if (head("$image")) {
		return "$image";
	}
	else {
		return "plugins/TVH/html/images/radiotower.png";
	}

}

1;