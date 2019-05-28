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
	my $username = $prefs->get('username');
	my $password = $prefs->get('password');

	if ($str =~ /^ *$/) {
		return 'http://' . $prefs->get('server') . ':' . $prefs->get('port') . '/';	
	}
	else {
		return 'http://' . $prefs->get('username') . ':' . $prefs->get('password') . '@' . $prefs->get('server') . ':' . $prefs->get('port') . '/';	
	}	
}

sub _getProfile {
	my $profile = $prefs->get('profile');

	if (!$str =~ /^ *$/) {
		return '?profile=' . $profile
	}
	else {
		return ""
	}
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
		stationsorting => 'NAME',
	});

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
	if (!$prefs->get('server')||!$prefs->get('port')) {
		$cb->([{ name => cstring($client, 'PLUGIN_TVH_NO_SETTINGS') }]);
		return;
	}

	$client = $client->master;

	my $items = [
		{
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

	Plugins::TVH::API->getStations(sub {
		my ($stations) = @_;

		my $items = _renderStations($stations, $tagUuid);

		if ($prefs->get('stationsorting') eq 'NAME') {
			@$items = sort {$a->{name} cmp $b->{name}} @$items;
		}
		else {
			@$items = sort {$a->{line2} <=> $b->{line2}} @$items;
		}

		$cb->({
			items => $items
		});
	});
}

sub _renderStations {
	my ($stations, $tag) = @_;

	my $items = [];

	for my $station (@$stations) {
		my (@tags) = $station->{tags};

		for my $row (@tags) {
			for my $element (@$row) { 
				if ($element eq $tag) {
					push @$items, {
						name => $station->{name},
						line1 => $station->{name},
						line2 => $station->{number},
						type => 'audio',
						image => _getStationImage($station->{icon_public_url}),  
						url => _getApiUrl() . 'stream/channelnumber/' . $station->{number} . _getProfile()
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
		return "plugins/TVH/html/images/radio.png";
	}

}

1;