#!/usr/local/cpanel/3rdparty/bin/perl

package test::cpev::blockers;

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockFile 0.032;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use Test::MockModule qw/strict/;

use Cpanel::JSON;

use cPstrict;

my $mock_fcp = Test::MockModule->new('File::Copy');
$mock_fcp->redefine(
    copy => sub ( $from, $to ) {

        # view https://github.com/cpanel/Test-MockFile/issues/176

        require File::Slurper;

        my $content = File::Slurper::read_binary($from);

        return File::Slurper::write_binary( $to, $content );
    }
);

my $stage_file  = Test::MockFile->file( cpev::ELEVATE_STAGE_FILE() );
my $marker_file = Test::MockFile->file( cpev::ELEVATE_SUCCESS_FILE() );

my $redhat_release = Test::MockFile->file(q[/etc/redhat-release]);
$redhat_release->contents("RHEL Before C7\nsome cruft");

my $cpev = bless {}, 'cpev';

is $cpev->elevation_startup_marker('deadbeef'), undef, 'elevation_startup_marker';
ok -e $stage_file->path,   "stage_file setup";
ok !-e $marker_file->path, "marker_file not setup after startup";

$redhat_release->contents("RHEL After A8");

is $cpev->elevation_success_marker(), undef, 'elevation_success_marker';
ok -e $stage_file->path,   "stage_file setup";
ok !-e $marker_file->path, "marker_file not setup after until we mark the elevate succeeded";

my $mock_cpev = Test::MockModule->new('cpev');
$mock_cpev->redefine(
    check_and_create_pidfile => 1,
    get_stage                => 5,
    get_current_status       => 'running',
    update_stage_file        => 1,
    _run_service             => 0,
    _notify_success          => 1,
);

$cpev->run_service_and_notify();
ok -e $marker_file->path, "marker_file is setup after elevate succeeds";

my $data = eval { Cpanel::JSON::LoadFile( $marker_file->path ) } // {};

is $data, {
    '_elevate_process' => {
        'cpanel_build'           => match qr{^[\d.]+$}a,
        'finished_at'            => match qr/^\d{4}-\d{1,2}-\d{1,2}[ T]\d{1,2}:\d{1,2}:\d{1,2}$/a,
        'script_md5'             => 'deadbeef',
        'started_at'             => match qr/^\d{4}-\d{1,2}-\d{1,2}[ T]\d{1,2}:\d{1,2}:\d{1,2}$/a,
        'redhat_release_pre'     => 'RHEL Before C7',
        'redhat_release_post'    => 'RHEL After A8',
        'elevate_version_start'  => cpev::VERSION,
        'elevate_version_finish' => cpev::VERSION,
    }
  },
  "stage file was stored to marker location with some data"
  or diag explain $data;

done_testing();
