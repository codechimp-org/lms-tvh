package Plugins::TVH::Settings;

use strict;
use base qw(Slim::Web::Settings);

use Slim::Utils::Prefs;

sub prefs {
	return ( preferences('plugin.TVH'), 'username' );
}

sub name {
	return 'PLUGIN_TVH';
}

sub page {
	return 'plugins/TVH/settings/basic.html';
}

1;
