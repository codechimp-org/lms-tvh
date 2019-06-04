package Plugins::TVH::Settings;

use strict;
use base qw(Slim::Web::Settings);
use Slim::Utils::Strings qw(string);
use Slim::Utils::Prefs;

my $prefs = preferences('plugin.TVH');

sub prefs {
	my @prefs = qw(server port username password profile stationsorting);
	return ($prefs, @prefs);
}

sub name {
	return Slim::Web::HTTP::CSRF->protectName('PLUGIN_TVH');
}

sub page {
	return Slim::Web::HTTP::CSRF->protectURI('plugins/TVH/settings/basic.html');
}

sub beforeRender {
	my $class = shift;
	my $params= shift;

	my @prefstationsortingOpts  =({ stationsorting  =>   'NAME',  stationsortingtext  => string('PLUGIN_TVH_STATION_SORTING_NAME')},				
								{ stationsorting  =>   'NUMBER',  stationsortingtext =>  string('PLUGIN_TVH_STATION_SORTING_NUMBER')});

	$params->{'pref_stationsortingopts'}  = \@prefstationsortingOpts;
}

sub handler {
	my ($class, $client, $params) = @_;
	
	return $class->SUPER::handler($client, $params);
}

1;
