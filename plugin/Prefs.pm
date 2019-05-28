package Plugins::TVH::Prefs;

my $LEVEL = 1;

use Slim::Utils::Strings qw(string cstring);
use Slim::Utils::Log;
use Slim::Utils::Prefs;

my $prefs = preferences('plugin.TVH');

sub getApiUrl {
	my $username = $prefs->get('username');
	my $password = $prefs->get('password');

	if ($str =~ /^ *$/) {
		return 'http://' . $prefs->get('server') . ':' . $prefs->get('port') . '/';	
	}
	else {
		return 'http://' . $prefs->get('username') . ':' . $prefs->get('password') . '@' . $prefs->get('server') . ':' . $prefs->get('port') . '/';	
	}	
}

sub getApiUrlNoAuth {
	return 'http://' . $prefs->get('server') . ':' . $prefs->get('port') . '/';
}

sub getProfile {
	my $profile = $prefs->get('profile');

	if (!$str =~ /^ *$/) {
		return '?profile=' . $profile
	}
	else {
		return ""
	}
}

1;