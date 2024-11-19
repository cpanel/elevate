#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use lib '/usr/local/cpanel/';

use Cpanel::OS              ();
use Cpanel::JSON            ();
use Cpanel::SafeRun::Simple ();

use Test::More;

# "Poor man's" FailWarnings
$SIG{'__WARN__'} = sub { fail("Warning detected: $_[0]"); };

is( Cpanel::OS->distro(),             'almalinux', 'System is Almalinux after upgrade.' );
is( Cpanel::OS->major(),              '8',         'Verson 8 of OS.' );
is( -e '/var/log/elevate-cpanel.log', 1,           'Elevate log exists.' );

note "Gather service status...";
my $svcstatus = run_api(qw{whmapi1 servicestatus});
if ( ref $svcstatus->{'data'}{'service'} eq 'ARRAY' ) {
    foreach my $svc_info ( $svcstatus->{'data'}{'service'}->@* ) {
        next if !$svc_info->{'enabled'} || $svc_info->{'name'} eq 'mailman' || $svc_info->{'name'} eq 'tailwatchd' || $svc_info->{'name'} eq 'imunify360';
        ok( $svc_info->{'running'}, "$svc_info->{'name'} is running" );
    }
}
ok( run(qw{pgrep elevate}) eq '', 'No instance of elevate-cpanel currently running.' );

# Do some basic checks for other things
# Sadly, we don't ship anything useful for login checks, so just use curl
my $login_url = run('/usr/sbin/whmlogin');
my $content   = curl($login_url);
like( $content, qr/<title>WHM/, "WHM is able to be logged into" );

like( run( qw{/usr/bin/bash -c}, 'echo "SHOW DATABASES" | mysql' ), qr/information_schema/, "MySQL seems OK" );

# XXX TODO randomize this, I really wish I had t/qa tools here. Also need to set allowunreg, etc. ;_;
note "Creating an account for testing...";
run_api( qw{whmapi1 set_tweaksetting value=1}, "key=$_" ) for qw{allowunregistereddomains allowremotedomains};
my $user = run_api(qw{whmapi1 createacct domain=azurediamond.test user=azurediamond pass=H4nt3r2_Als0_B1FF_R00LZ});
note "Waiting on taskqueue...";
run(qw{/usr/local/cpanel/3rdparty/bin/servers_queue run});
$login_url = run_api(qw{whmapi1 create_user_session user=azurediamond service=cpaneld})->{'data'}{'url'};
$content   = curl($login_url);
like( $content, qr/<title>cPanel/, "cPanel is able to be logged into with newly created user" );

# Delete the account. Possibly should be done in an END block but meh.
# VM will get whacked after pipeline runs, so *for now* this should be fine.
note "Deleting created account...";
run_api(qw{whmapi1 removeacct user=azurediamond});

done_testing();

# Less typing, it all needs the chomp
sub run {
    my $out = Cpanel::SafeRun::Simple::saferun(@_);
    chomp $out;
    return $out;
}

sub curl {
    return run( qw{curl -s -k -L}, @_ );
}

# Returns HASHREF. For "script only opts" like --user, etc., use `--` to separate after API args.
sub run_api {
    my ( $api, @call_args ) = @_;
    my $out = {};
    {
        local $@;
        $out = eval { Cpanel::JSON::Load( run( "/usr/local/cpanel/bin/$api", '--output=json', @call_args ) ) };
        warn $@ if $@;
    }
    warn "$api @call_args failed: $out->{'metadata'}{'reason'}" if !$out->{'metadata'}{'result'};
    return $out;
}
