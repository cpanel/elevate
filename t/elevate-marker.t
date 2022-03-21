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

my $cpev = bless {}, 'cpev';

is $cpev->elevation_startup_marker('deadbeef'), undef, 'elevation_startup_marker';
ok -e $stage_file->path,   "stage_file setup";
ok !-e $marker_file->path, "marker_file not setup after startup";

is $cpev->elevation_success_marker(), undef, 'elevation_success_marker';
ok -e $stage_file->path,  "stage_file setup";
ok -e $marker_file->path, "marker_file setup after startup";

my $data = eval { Cpanel::JSON::LoadFile( $marker_file->path ) } // {};

is $data, {
    '_elevate_process' => {
        'cpanel_build' => match qr{^[\d.]+$}a,
        'finished_at'  => D(),
        'script_md5'   => 'deadbeef',
        'started_at'   => D()
    }
  },
  "stage file was stored to marker location with some data"
  or diag explain $data;

done_testing();
