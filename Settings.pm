package Plugins::TVH::Settings;

use strict;
use base qw(Slim::Web::Settings);

use Slim::Utils::Prefs;

my $prefs = preferences('plugin.TVH');

sub prefs {
	my @prefs = qw(server username password tag);
	return ($prefs, @prefs);
}

sub name {
	return 'PLUGIN_TVH';
}

sub page {
	return 'plugins/TVH/settings/basic.html';
}

1;
