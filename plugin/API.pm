package Plugins::TVH::API;

use strict;

use Digest::MD5 qw(md5_hex);
use JSON::XS::VersionOneAndTwo;
# use List::Util qw(min max);
# use POSIX qw(strftime);
# use Tie::Cache::LRU::Expires;
# use URI::Escape qw(uri_escape_utf8);
use Encode;

use Slim::Networking::SimpleAsyncHTTP;
use Slim::Utils::Cache;
use Slim::Utils::Log;
use Slim::Utils::Prefs;

use constant CACHE_TTL => 3600;

use Scalar::Util qw(blessed dualvar isdual readonly refaddr reftype
                        tainted weaken isweak isvstring looks_like_number
                        set_prototype);

my $prefs = preferences('plugin.TVH');
my $api_url = 'http://' . $prefs->get('username') . ':' . $prefs->get('password') . '@' . $prefs->get('server') . ':' . $prefs->get('port') . '/';

my $log = logger('plugin.TVH');
my $cache = Slim::Utils::Cache->new();

# The following apply to each of decode_struct_inplace, encode_struct_inplace, downgrade_struct_inplace and upgrade_struct_inplace:
# - Errors are silently ignored. The scalar is left unchanged.
# - Recognizes references to arrays, hashes and scalars. More esoteric references won't processed, and a warning will be issued.
# - Overloaded objects and magical variables are not supported. They may induce incorrect behaviour.
# - The structure is changed in-place. You can use Storable::dclone to make a copy first if need be.
# - For convenience, returns its argument.

# Decodes all strings in a data structure from UTF-8 to Unicode Code Points.
sub decode_struct_inplace { _convert_struct_inplace($_[0], \&utf8::decode) }

# Encodes all strings in a data structure from Unicode Code Points to UTF-8.
sub encode_struct_inplace { _convert_struct_inplace($_[0], \&utf8::encode) }

# "Downgrades" the string storage format of all scalars containing strings in
# a data structure to the UTF8=0 format if they aren't already in that format.
sub downgrade_struct_inplace { _convert_struct_inplace($_[0], \&utf8::downgrade) }

# "Upgrades" the string storage format of all scalars containing strings in
# a data structure to the UTF8=1 format if they aren't already in that format.
sub upgrade_struct_inplace { _convert_struct_inplace($_[0], \&utf8::upgrade) }

sub _convert_struct_inplace {
    # Make $arg an alias to $_[0]. Changes to $arg (like changes to $_[0]) will be reflected in the parent.
    our $arg; local *arg = \shift;
    my $converter        =  shift;

    my $caller = (caller(1))[3];
    $caller =~ s/^.*:://;    # /

    my %seen;    # Only decode each variable once.
    my %warned;  # Only emit each warning once.

    # Using "my" would introduce a memory cycle we'd have to work to break to avoid a memory leak.
    local *_visitor = sub {
        # Make $arg an alias to $_[0]. Changes to $arg (like changes to $_[0]) will be reflected in the parent.
        our $arg; local *arg = \$_[0];

        # Don't decode the same variable twice.
        # Also detects referential loops.
        return $arg if $seen{refaddr(\$arg)}++;

        my $reftype = reftype($arg);
        if (!defined($reftype)) {
            if (defined($arg)) {
                my $sv = B::svref_2object(\$arg);  # Meta object.
                if ($sv->isa('B::PV') && ($sv->FLAGS & B::SVf_POK)) {  # Can it contain a string? And does it?
                    $converter->($arg);
                }
            }
        }
        elsif ($reftype eq 'ARRAY') {
            _visitor($_) for @$arg;
        }
        elsif ($reftype eq 'HASH') {
            # Usually, we can avoid converting the keys.
            my $ascii = 1;
            for (keys(%$arg)) {
                if (/[^\x00-\x7F]/) {
                    $ascii = 0;
                    last;
                }
            }

            if (!$ascii) {
                %$arg = map {
                        $converter->( my $new_key = $_ );
                        $new_key => $arg->{$_}
                    } keys(%$arg);
            }

            _visitor($_) for values(%$arg);
        }
        elsif ($reftype eq 'SCALAR') {
            _visitor($$arg);
        }
        elsif ($reftype eq 'REF') {
            _visitor($$arg);
        }
        else {
            warn("Reference type $reftype not supported by $caller\n")
                if !$warned{$reftype}++;
        }

        return $arg;
    };

    return _visitor($arg);
}

sub getStations {
	my ($class, $cb) = @_;
	_call('/api/channel/grid?limit=500', $cb);
}

sub getStationsNotWorking {
	my ($class, $cb) = @_;

	getChannelTagUuid(sub {
		my ($uuid) = @_;

		$log->error('TVH getStations using tag uuid: (' . $uuid . ')');
		_call('/api/channel/grid', sub {
			my ($channels) = @_;

			$log->error('TVH getStations channels is an ' . $channels);

			my $stations = [];

			foreach (@$channels) {
				my ($channel) = @_;

				my (@tags) = $_->{tags};
				
				$log->error('TVH getStations assessing channel: ' . $_->{name} . ' (' . $tags[0][0] . ')' );

				if ($tags[0][0] == $uuid) {
					push @$stations, [$channel] ;
					#{
					#	name => $channel->{name},
					#	number => $channel->{number},
					#	icon_public_url => $channel->{icon_public_url}
					#};
					$log->error('Added!');
				}
			}

			$log->error('TVH getStations calling back');
			$cb->($stations);
		});
	});
}

sub getChannelTagUuid {
	my ($cb) = @_;

	my $uuid = '';
	_call('/api/channeltag/list', sub {
		my ($tags) = @_;

		foreach (@$tags) {
			my ($tag) = @_;
			
			if (@$tag[0]->{val} == 'Radio channels') {
				$uuid = @$tag[0]->{key};
			}
		}

		$log->error('TVH getChannelTagUuid found uuid: (' . $uuid . ')');
		$cb->($uuid);
	});
}

sub getTags {
	my ($class, $cb) = @_;
	_call('/api/channeltag/list', $cb);
}

sub getRecordings {
	my ($class, $cb) = @_;
	_call('/api/dvr/entry/grid_finished?limit=500', $cb);
}


sub _call {
	my ( $url, $cb, $params ) = @_;

	# $uri must not have a leading slash
	$url =~ s/^\///;
	$url = $api_url . $url;

	$params->{per_page} ||= 9999;

	if ( my @keys = sort keys %{$params}) {
		my @params;
		foreach my $key ( @keys ) {
			next if $key =~ /^_/;
			push @params, $key . '=' . $params->{$key};
			# push @params, $key . '=' . uri_escape_utf8( $params->{$key} );
		}

		$url .= '?' . join( '&', sort @params ) if scalar @params;
	}

	my $cached;
	my $cache_key;
	if (!$params->{_nocache}) {
		$cache_key = md5_hex($url);
	}

	main::INFOLOG && $log->is_info && $cache_key && $log->info("Trying to read from cache for $url");

	if ( $cache_key && ($cached = $cache->get($cache_key)) ) {
		main::INFOLOG && $log->is_info && $log->info("Returning cached data for $url");
		main::DEBUGLOG && $log->is_debug && $log->debug(Data::Dump::dump($cached));
		$cb->($cached);
		return;
	}
	elsif ( main::INFOLOG && $log->is_info ) {
		$log->info("API call: $url");
	}

my $http = Slim::Networking::SimpleAsyncHTTP->new(
		sub {
			my $response = shift;
			my $params   = $response->params('params');

			my $result;

			if ( $response->headers->content_type =~ /json/i ) {
				$log->error('TVH got a response: ' . $response->content);
				$result = decode_json(
					$response->content,
				);
			}
			else {
				$log->error("TVHeadend didn't return JSON data? " . $response->content);
			}

			main::DEBUGLOG && $log->is_debug && $log->debug(Data::Dump::dump($result));

			if ($result && $result->{entries}) {
				$result = $result->{entries};

				if ( $cache_key ) {
					if ( my $cache_control = $response->headers->header('Cache-Control') ) {
						my ($ttl) = $cache_control =~ /max-age=(\d+)/;

						$ttl ||= CACHE_TTL;		# XXX - we're going to always cache for a while, as we often do follow up calls while navigating

						if ($ttl) {
							main::INFOLOG && $log->is_info && $log->info("Caching result for $ttl using max-age (" . $response->url . ")");
							$cache->set($cache_key, $result, $ttl);
							main::INFOLOG && $log->is_info && $log->info("Data cached (" . $response->url . ")");
						}
					}
				}
			}

			$cb->($result, $response);
		},
		sub {
			my ($http, $error, $response) = @_;

			$log->error("Got error': $error");

			main::INFOLOG && $log->is_info && $log->info(Data::Dump::dump($response));
			$cb->({
				error => 'Unexpected error: ' . $error,
			}, $response);
		},
	);

	$http->get($url);
}

1;