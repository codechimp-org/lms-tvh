package Plugins::TVH::Plugin;

use strict;

use base qw(Slim::Plugin::OPMLBased);

use Slim::Utils::Strings qw(string cstring);
use Slim::Utils::Log;

use Plugins::TVH::API;
use Plugins::TVH::Metadata;

use vars qw($VERSION);

my $log = Slim::Utils::Log->addLogCategory( {
	category     => 'plugin.TVH',
	defaultLevel => 'WARN',
	description  => 'PLUGIN_TVH',
} );

sub initPlugin {
	my $class = shift;

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

	$client = $client->master;

	my $items = [
		{
			name => cstring($client, 'PLUGIN_TVH_YEARS'),
			type => 'link',
			url  => \&eras,
		},{
			name => cstring($client, 'PLUGIN_TVH_VENUES'),
			type => 'link',
			url  => \&venues,
		},{
			name => cstring($client, 'PLUGIN_TVH_SONGS'),
			type => 'link',
			url  => \&songs,
		},{
			name => cstring($client, 'PLUGIN_TVH_PLACES'),
			type => 'link',
			url  => \&venuesByPlaces,
		},{
			name => cstring($client, 'PLUGIN_TVH_SEARCH'),
			type => 'search',
			url  => \&search,
		}
	];

	$cb->({
		items => $items,
	});
}

sub eras {
	my ($client, $cb, $params) = @_;

	Plugins::TVH::API->getEras(sub {
		my ($eras) = @_;

		my $items = [];
		foreach my $era ( sort { $b <=> $a } keys %$eras ) {
			push @$items, {
				name => cstring($client, 'PLUGIN_TVH_ERA', $era),
				type => 'outline',
				items => [ map {
					{
						name => $_,
						url => \&year,
						passthrough => [{
							year => $_
						}],
					}
				} reverse @{$eras->{$era}} ]
			}
		}

		$cb->({ items => $items });
	});
}

sub year {
	my ($client, $cb, $params, $args) = @_;

	Plugins::TVH::API->getYear($params->{year} || $args->{year}, sub {
		my ($shows) = @_;

		my $items = [ map {
			{
				name => $_->{date} . ' - ' . $_->{venue}->{name} . ' - ' . $_->{venue}->{location},
				line1 => $_->{date} . ' - ' . $_->{venue}->{name},
				line2 => $_->{venue}->{location},
				type => 'playlist',
				url => \&show,
				passthrough => [{
					showId => $_->{id}
				}]
			}
		} @$shows ];

		$cb->({ items => $items });
	});
}

sub venues {
	my ($client, $cb, $params, $args) = @_;

	Plugins::TVH::API->getVenues(sub {
		my ($venues) = @_;

		my ($items, $indexList) = _renderVenues($venues);

		$cb->({
			items     => $items,
			indexList => $indexList
		});
	});
}

sub _renderVenues {
	my ($venues) = @_;

	my $items = [];
	my $indexList = [];
	my $indexLetter;
	my $count = 0;

	foreach (@$venues) {
		next unless $_->{shows_count};

		my $textkey = uc(substr($_->{name} || '', 0, 1));

		if ( defined $indexLetter && $indexLetter ne ($textkey || '') ) {
			push @$indexList, [$indexLetter, $count];
			$count = 0;
		}

		$count++;
		$indexLetter = $textkey;

		push @$items, {
			name => $_->{name} . ' - ' . $_->{location},
			line1 => $_->{name},
			line2 => join(', ', grep { $_ } ($_->{city}, $_->{state}, $_->{country})),
			type => 'link',
			textkey => $textkey,
			url => \&venue,
			passthrough => [{
				venueId => $_->{id}
			}]
		}
	}

	push @$indexList, [$indexLetter, $count];

	return wantarray ? ($items, $indexList) : $items;
}

sub venuesByPlaces {
	my ($client, $cb, $params, $args) = @_;

	Plugins::TVH::API->getVenues(sub {
		my ($venues) = @_;

		my %venues;
		my %noState;
		foreach (@$venues) {
			my $country = $_->{country} ||= 'USA';
			$country    = 'USA' if $country eq 'US';
			my $state   = $_->{state};

			$noState{$country}++ unless $state;
			$venues{$country} ||= {};
			$venues{$country}->{$state} ||= [];
			push @{$venues{$country}->{$state}}, $_;
		}

		my $items = [];

		foreach my $country (sort keys %venues) {
			my $subItems = [];

			if ($noState{$country}) {
				$subItems = _renderVenues($venues{$country}->{''});
			}
			else {
				$subItems = [ map {
					{
						name => $_,
						type => 'outline',
						items => _renderVenues($venues{$country}->{$_})
					}
				} sort { lc($a) cmp lc($b) } keys %{$venues{$country}} ]
			}

			push @$items, {
				name => $country,
				type => 'outline',
				items => $subItems
			};
		}

		$cb->({
			items => $items,
		});
	});
}

sub venue {
	my ($client, $cb, $params, $args) = @_;

	Plugins::TVH::API->getVenue($params->{venueId} || $args->{venueId}, sub {
		my ($venue) = @_;

		my $i = 0;
		my $items = [ reverse map {
			{
				name => $_,
				type => 'playlist',
				url => \&show,
				passthrough => [{
					showId => $venue->{show_ids}->[$i++]
				}]
			}
		} @{$venue->{show_dates} || []} ];

		$cb->({ items => $items });
	});
}

sub songs {
	my ($client, $cb, $params, $args) = @_;

	Plugins::TVH::API->getSongs(sub {
		my ($songs) = @_;

		my $items = [];

		my $indexList = [];
		my $indexLetter;
		my $count = 0;

		foreach (@$songs) {
			next unless $_->{tracks_count};

			my $textkey = uc(substr($_->{title} || '', 0, 1));

			if ( defined $indexLetter && $indexLetter ne ($textkey || '') ) {
				push @$indexList, [$indexLetter, $count];
				$count = 0;
			}

			$count++;
			$indexLetter = $textkey;

			push @$items, {
				name => $_->{title} . ' (' . $_->{tracks_count} . ')',
				type => 'link',
				textkey => $textkey,
				url => \&song,
				passthrough => [{
					songId => $_->{id}
				}]
			}
		}

		push @$indexList, [$indexLetter, $count];

		$cb->({
			items     => $items,
			indexList => $indexList
		});
	});
}

sub song {
	my ($client, $cb, $params, $args) = @_;

	Plugins::TVH::API->getSong($params->{songId} || $args->{songId}, sub {
		my ($song) = @_;

		my $i = 0;
		my $items = [ reverse map {
			{
				name => $_->{show_date},
				type => 'playlist',
				url => \&show,
				passthrough => [{
					showId => $_->{show_id}
				}]
			}
		} @{$song->{tracks} || []} ];

		$cb->({ items => $items });
	});
}

sub show {
	my ($client, $cb, $params, $args) = @_;

	Plugins::TVH::API->getShow($params->{showId} || $args->{showId}, sub {
		my ($show) = @_;

		my $items = [ map {
			my $meta = Plugins::TVH::Metadata->setMetadata($_, $show);

			{
				name => $meta->{title},
				type => 'audio',
				url  => $meta->{url},
			}
		} @{$show->{tracks}} ];

		$cb->({ items => $items });
	});
}

sub search {
	my ($client, $cb, $params, $args) = @_;

	Plugins::TVH::API->search($params->{search} || $args->{q}, sub {
		my ($results) = @_;

		my $items = [];

		if ($results->{songs}) {
			push @$items, {
				name => cstring($client, 'PLUGIN_TVH_SONGS'),
				type => 'outline',
				items => [ map {
					{
						name => $_->{title} . ' (' . $_->{tracks_count} . ')',
						type => 'link',
						url => \&song,
						passthrough => [{
							songId => $_->{id}
						}]
					}
				} @{$results->{songs}} ]
			};
		}

		if ($results->{venues}) {
			push @$items, {
				name => cstring($client, 'PLUGIN_TVH_VENUES'),
				type => 'outline',
				items => [ map {
					{
						name => $_->{name} . ' - ' . $_->{location},
						line1 => $_->{name},
						line2 => $_->{location},
						type => 'link',
						url => \&venue,
						passthrough => [{
							venueId => $_->{id}
						}]
					}
				} @{$results->{venues}} ]
			};
		}

		$cb->({ items => $items });
	});
}

1;