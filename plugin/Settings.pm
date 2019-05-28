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
	if ($params->{'saveSettings'}) 	{				# SAVE MODE
		my $server = $params->{'pref_server'};
		$prefs->set('server', "$server");
		my $port = $params->{'pref_port'};
		$prefs->set('port', "$port");
		my $username = $params->{'pref_username'};
		$prefs->set('username', "$username");		
		my $password = $params->{'pref_password'};
		$prefs->set('password', "$password");
		my $profile = $params->{'pref_profile'};
		$prefs->set('profile', "$profile");
		my $stationsorting = $params->{'pref_stationsorting'};
		$prefs->set('stationsorting', "$stationsorting");
	}				
	
	# LOAD
	$params->{'prefs'}->{'pref_server'} = $prefs->get('server');
	$params->{'prefs'}->{'pref_port'} = $prefs->get('port');
	$params->{'prefs'}->{'pref_username'} = $prefs->get('username');
	$params->{'prefs'}->{'pref_password'} = $prefs->get('password');
	$params->{'prefs'}->{'pref_profile'} = $prefs->get('profile');
	$params->{'prefs'}->{'pref_stationsorting'} = $prefs->get('stationsorting');
	
	return $class->SUPER::handler($client, $params);
}

1;
