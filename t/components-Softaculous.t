#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

package test::cpev::components;

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;
use Test2::Tools::Mock;

use Test::MockModule qw/strict/;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use Cpanel::Exception ();
use File::Temp        ();

use cPstrict;

my $comp = cpev->new->get_component('Softaculous');

{
    note "Checking pre_distro_upgrade";

    ok( length $comp->cli_path, 'cli_path defaults to a reasonable string' );

    my $mock_run = Test::MockModule->new('Elevate::Components::Softaculous');

    $comp->cli_path('/file/does/not/exist');
    $mock_run->redefine( _run_script => sub { die "I shouldn't run yet!" } );

    ok( lives { $comp->pre_distro_upgrade() }, "Short-circuits if Softaculous CLI script does not exist" );
    no_messages_seen();

    my $tempfile = File::Temp->new();
    $comp->cli_path( $tempfile->filename );

    my ( $stdout, $exec_failed, $exception );
    $mock_run->redefine(
        _run_script => sub {
            return mock {} => (
                add => [
                    stdout       => sub { return $stdout },
                    exec_failed  => sub { return $exec_failed },
                    to_exception => sub { return $exception },
                ],
            );
        }
    );

    $stdout      = '1.2.3';
    $exec_failed = 0;
    $exception   = undef;

    ok( lives { $comp->pre_distro_upgrade() }, "Runs correctly with no errors" );
    message_seen( INFO => 'Softaculous has been detected. The system will re-install that software after the distro upgrade.' );
    no_messages_seen();

    $exec_failed = 1;
    ok( lives { $comp->pre_distro_upgrade() }, "Short-circuits if SafeRun could not exec()" );
    no_messages_seen();

    $exec_failed = 0;
    $exception   = Cpanel::Exception::create( 'ProcessFailed::Error' => [ error_code => 1 ] );
    ok( lives { $comp->pre_distro_upgrade() }, "Short-circuits if script exits with error" );
    no_messages_seen();

    $exception = undef;
    $stdout    = undef;
    ok( lives { $comp->pre_distro_upgrade() }, "Runs correctly but returns no data (can this even happen?)" );
    no_messages_seen();
}

done_testing();
