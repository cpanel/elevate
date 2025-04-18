#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2025 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use lib '/usr/local/cpanel/';

use Cpanel::JSON            ();
use Cpanel::SafeRun::Simple ();
use Cpanel::SafeRun::Object ();

use Test::More;
plan tests => 8;

# "Poor man's" FailWarnings
$SIG{'__WARN__'} = sub { fail("Warning detected: $_[0]"); };

note "Waiting on taskqueue...";
run_get_output(qw{/usr/local/cpanel/bin/servers_queue run});

is( -e '/var/log/elevate-cpanel.log', 1, 'Elevate log exists.' );

note "Gather service status...";
subtest 'Enabled and running services' => sub {
    my $svcstatus = run_api(qw{whmapi1 servicestatus});
    if ( ref $svcstatus->{'data'}{'service'} eq 'ARRAY' ) {
        foreach my $svc_info ( $svcstatus->{'data'}{'service'}->@* ) {
            next if !$svc_info->{'enabled'} || $svc_info->{'name'} eq 'mailman' || $svc_info->{'name'} eq 'tailwatchd' || $svc_info->{'name'} eq 'imunify360';
            ok( $svc_info->{'running'}, "$svc_info->{'name'} is running" );
        }
    }
};
ok( run_get_output(qw{pgrep elevate}) eq '', 'No instance of elevate-cpanel currently running.' );

# Do some basic checks for other things

# RE-1179 / RE-1244
is( run_get_status_code(qw{/usr/local/cpanel/bin/rebuild_phpconf --current}), 0, 'rebuild_phpconf returns cleanly' );

# RE-1416 / RE-1461
subtest 'httpd and nginx sanity' => sub {
    plan tests => 6;
    like( run_get_output(qw{file /usr/sbin/httpd}),                                qr/httpd: ELF 64-bit LSB/,       'httpd binary executable exists' );
    like( run_get_output(qw{/usr/sbin/httpd -t}),                                  qr/Syntax OK/,                   'httpd config syntax is valid' );
    like( run_get_output(qw{/usr/local/cpanel/scripts/restartsrv_httpd --status}), qr/is running as root with PID/, 'httpd service status is running' );
    like( run_get_output(qw{file /usr/sbin/nginx}),                                qr/nginx: ELF 64-bit LSB/,       'nginx binary executable exists' );
    like( run_get_output(qw{/usr/sbin/nginx -t}),                                  qr/test is successful/,          'nginx config syntax is valid' );
    like( run_get_output(qw{/usr/local/cpanel/scripts/restartsrv_nginx --status}), qr/is running as root with PID/, 'nginx service status is running' );
};

# Sadly, we don't ship anything useful for login checks, so just use curl
my $login_url = run_get_output('/usr/sbin/whmlogin');
my $content   = curl($login_url);
like( $content, qr/<title>WHM/, "WHM is able to be logged into" );

like( run_get_output( qw{/usr/bin/bash -c}, 'echo "SHOW DATABASES" | mysql' ), qr/information_schema/, "MySQL seems OK" );

# XXX TODO randomize this, I really wish I had t/qa tools here. Also need to set allowunreg, etc. ;_;
note "Creating an account for testing...";
run_api( qw{whmapi1 set_tweaksetting value=1}, "key=$_" ) for qw{allowunregistereddomains allowremotedomains};
my $user = run_api(qw{whmapi1 createacct domain=azurediamond.test user=azurediamond});
note "Waiting on taskqueue...";
run_get_output(qw{/usr/local/cpanel/bin/servers_queue run});
$login_url = run_api(qw{whmapi1 create_user_session user=azurediamond service=cpaneld})->{'data'}{'url'};
$content   = curl($login_url);
like( $content, qr/<title>cPanel/, "cPanel is able to be logged into with newly created user" );

# VM will get whacked after pipeline runs, so *for now* this should be fine.

done_testing();

# Less typing, it all needs the chomp
sub run_get_output {
    my $out = Cpanel::SafeRun::Simple::saferunallerrors(@_);
    chomp $out if defined $out;
    return $out;
}

sub run_get_status_code {
    my ( $program, @args ) = @_;

    my $run = Cpanel::SafeRun::Object->new(
        program => $program,
        args    => \@args,
    );

    return $run->CHILD_ERROR();
}

sub curl {
    return run_get_output( qw{curl -s -k -L}, @_ );
}

# Returns HASHREF. For "script only opts" like --user, etc., use `--` to separate after API args.
sub run_api {
    my ( $api, @call_args ) = @_;
    my $out = {};
    {
        local $@;
        $out = eval { Cpanel::JSON::Load( run_get_output( "/usr/local/cpanel/bin/$api", '--output=json', @call_args ) ) };
        warn $@ if $@;
    }
    warn "$api @call_args failed: $out->{'metadata'}{'reason'}" if !$out->{'metadata'}{'result'};
    return $out;
}
