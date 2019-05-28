package Plugins::TVH::Settings;

use strict;
use base qw(Slim::Web::Settings);
use Slim::Utils::Prefs;

my $prefs = preferences('plugin.TVH');

sub prefs {
	my @prefs = qw(server port username password tag, stationsorting);
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

	my @prefstationsortingOpts  =({ stationsorting  =>   cstring($client, 'PLUGIN_TVH_STATION_SORTING_NAME'),  stationsortingtext  => cstring($client, 'PLUGIN_TVH_STATION_SORTING_NAME')},				
								{ stationsorting  =>   cstring($client, 'PLUGIN_TVH_STATION_SORTING_NUMBER'),  stationsortingtext =>  cstring($client, 'PLUGIN_TVH_STATION_SORTING_NUMBER')});

	$params->{'stationsortingopts'}  = \@prefstationsortingOpts;
}

sub handler {
	my ($class, $client, $params) = @_;
	if ($params->{'saveSettings'}) 	{				# SAVE MODE
		my $server = $params->{'server'};
		$prefs->set('server', "$server");
		my $port = $params->{'port'};
		$prefs->set('port', "$port");
		my $username = $params->{'username'};
		$prefs->set('username', "$username");		
		my $password = $params->{'password'};
		$prefs->set('password', "$password");
		my $stationsorting = $params->{'stationsorting'};
		$prefs->set('stationsorting', "$stationsorting");
	}				
	
	# LOAD
	$params->{'prefs'}->{'server'} = $prefs->get('server');
	$params->{'prefs'}->{'port'} = $prefs->get('port');
	$params->{'prefs'}->{'username'} = $prefs->get('username');
	$params->{'prefs'}->{'password'} = $prefs->get('password');
	$params->{'prefs'}->{'stationsorting'} = $prefs->get('stationsorting');
	
	return $class->SUPER::handler($client, $params);
}

1;
