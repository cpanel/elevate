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

my $mock_stage_file = Test::MockModule->new('Elevate::StageFile');
my $stage_data;
$mock_stage_file->redefine( _read_stage_file => sub { return $stage_data } );
$mock_stage_file->redefine( _save_stage_file => sub { $stage_data = $_[0]; return 1 } );

{
    note "Checking pre_distro_upgrade";

    ok( length $comp->cli_path, 'cli_path defaults to a reasonable string' );

    my $mock_run = Test::MockModule->new('Elevate::Components::Softaculous');

    $comp->cli_path('/file/does/not/exist');
    $mock_run->redefine( _run_script => sub { die "I shouldn't run yet!" } );
    ok( lives { $comp->pre_distro_upgrade() }, "Short-circuits if Softaculous CLI script does not exist" );
    ok( !defined $stage_data,                  "Stage file unchanged" );
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

    $stdout      = "1.2.3\n";
    $exec_failed = 0;
    $exception   = undef;

    ok( lives { $comp->pre_distro_upgrade() }, "Runs correctly with no errors" );
    is( $stage_data, { softaculous => '1.2.3' }, "Stage file has evidence of Softaculous" );
    message_seen( INFO => 'Softaculous has been detected. The system will re-install that software after the distro upgrade.' );
    no_messages_seen();

    $stage_data  = undef;
    $exec_failed = 1;
    ok( lives { $comp->pre_distro_upgrade() }, "Short-circuits if SafeRun could not exec()" );
    ok( !defined $stage_data,                  "Stage file unchanged" );
    no_messages_seen();

    $exec_failed = 0;
    $exception   = Cpanel::Exception::create( 'ProcessFailed::Error' => [ error_code => 1 ] );
    ok( lives { $comp->pre_distro_upgrade() }, "Short-circuits if script exits with error" );
    ok( !defined $stage_data,                  "Stage file unchanged" );
    no_messages_seen();

    $exception = undef;
    $stdout    = undef;
    ok( lives { $comp->pre_distro_upgrade() }, "Runs correctly but returns no data (can this even happen?)" );
    ok( !defined $stage_data,                  "Stage file unchanged" );
    no_messages_seen();
}

{
    note "Checking post_distro_upgrade";

    my $mock_fetch = Test::MockModule->new('Elevate::Fetch');
    $mock_fetch->redefine( script => sub { die "I shouldn't run yet!" } );

    my $mock_path = Test::MockModule->new('Cpanel::Binaries');
    $mock_path->redefine( path => sub { die "I shouldn't run yet!" } );

    $stage_data = {};
    ok( lives { $comp->post_distro_upgrade() }, "Short-circuits if no Softaculous data in stage file" );
    no_messages_seen();

    $stage_data = { softaculous => '1.2.3' };
    $mock_fetch->redefine( script => sub { return undef } );
    ok( lives { $comp->post_distro_upgrade() }, "Emits error if no Softaculous installer couldn't be downloaded" );
    message_seen( ERROR => 'Failed to download Softaculous installer.' );
    no_messages_seen();

    $mock_fetch->redefine( script => '/path/to/script' );
    $mock_path->redefine( path => '/bin/false' );
    ok( lives { $comp->post_distro_upgrade() }, "Emits error if Softaculous installer exited non-zero" );
    message_seen( INFO => 'Re-installing Softaculous:' );

    # Account for ssystem log entries:
    message_seen( INFO => 'Running: /bin/false /path/to/script --reinstall' );
    message_seen( INFO => '' );
    message_seen( INFO => '' );

    message_seen( ERROR => 'Re-installation of Softaculous failed.' );
    no_messages_seen();

    $mock_path->redefine( path => '/bin/echo' );
    ok( lives { $comp->post_distro_upgrade() }, "Runs successfully" );
    message_seen( INFO => 'Re-installing Softaculous:' );

    # Account for ssystem log entries:
    message_seen( INFO => 'Running: /bin/echo /path/to/script --reinstall' );
    message_seen( INFO => '' );
    message_seen( INFO => '/path/to/script --reinstall' );
    message_seen( INFO => '' );
    no_messages_seen();
}

done_testing();
