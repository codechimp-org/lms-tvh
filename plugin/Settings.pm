package Plugins::TVH::Settings;

use strict;
use base qw(Slim::Web::Settings);
use Slim::Utils::Prefs;

my $prefs = preferences('plugin.TVH');

sub prefs {
	my @prefs = qw(server port username password tag);
	return ($prefs, @prefs);
}

sub name {
	return Slim::Web::HTTP::CSRF->protectName('PLUGIN_TVH');
}

sub page {
	return Slim::Web::HTTP::CSRF->protectURI('plugins/TVH/settings/basic.html');
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
		my $tag = $params->{'tag'};
		$prefs->set('tag', "$tag");	
	}				
	
	# LOAD
	$params->{'prefs'}->{'server'} = $prefs->get('server');
	$params->{'prefs'}->{'port'} = $prefs->get('port');
	$params->{'prefs'}->{'username'} = $prefs->get('username');
	$params->{'prefs'}->{'password'} = $prefs->get('password');
	$params->{'prefs'}->{'tag'} = $prefs->get('tag');
	
	return $class->SUPER::handler($client, $params);
}

1;
