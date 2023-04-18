#!/usr/local/cpanel/3rdparty/bin/perl

# HARNESS-NO-STREAM

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockModule qw/strict/;

use FindBin;

use Test::MockFile 0.032;
use Log::Log4perl;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

require $FindBin::Bin . q[/../elevate-cpanel];

use cPstrict;

$INC{'scripts/ElevateCpanel.pm'} = '__TEST__';

my $mock_elevate = Test::MockModule->new('cpev');
my $mock_pecl    = Test::MockModule->new('Elevate::Components::PECL');

my $mock_stage_file = Test::MockFile->file( cpev::ELEVATE_STAGE_FILE() );

my $list_output;

my $mock_saferun = Test::MockModule->new('Cpanel::SafeRun::Simple');
$mock_saferun->redefine(
    saferunnoerror => sub {
        return $list_output;

    }
);

my $pecl_bin = Test::MockFile->file( '/my/pecl/bin', '', { mode => 0700 } );

my $cpev = cpev->new;
my $pecl = $cpev->component('PECL');

is Elevate::Components::PECL::_get_pecl_installed_for('/my/pecl/bin'), undef, '_get_pecl_installed_for - empty list';

$list_output = qq[(no packages installed from channel pecl.php.net)\n];

is Elevate::Components::PECL::_get_pecl_installed_for('/my/pecl/bin'), undef, '_get_pecl_installed_for - no packages installed';

$list_output = <<'EOS';
Installed packages, channel pecl.php.net:
=========================================
Package Version State
imagick 3.5.1   stable
EOS

is Elevate::Components::PECL::_get_pecl_installed_for('/my/pecl/bin'), {
    imagick => q[3.5.1],
  },
  '_get_pecl_installed_for - imagick';

$list_output = <<'EOS';
Installed packages, channel pecl.php.net:
=========================================
Package Version State
ds      1.4.0   stable
imagick 3.5.1   stable
EOS

is Elevate::Components::PECL::_get_pecl_installed_for('/my/pecl/bin'), {
    ds      => q[1.4.0],
    imagick => q[3.5.1],
  },
  '_get_pecl_installed_for - ds + imagick';

{

    is cpev::read_stage_file(), {}, "stage file is empty";

    $mock_pecl->redefine( _get_pecl_installed_for => sub { { module_one => 1.2 } } );

    Elevate::Components::PECL::_store_pecl_for( '/whatever', 'cpanel' );

    is cpev::read_stage_file(), { pecl => { cpanel => { module_one => 1.2 } } }, "stage file: store pecl for cpanel";

    $mock_pecl->redefine( _get_pecl_installed_for => sub { { xyz => 5.6 } } );
    Elevate::Components::PECL::_store_pecl_for( '/whatever', 'ea-php80' );

    is cpev::read_stage_file(), {
        pecl => {
            cpanel     => { module_one => 1.2 },
            'ea-php80' => { xyz        => 5.6 }
        }
      },
      "stage file: store pecl for cpanel & ea-php80";

}

{
    $mock_pecl->redefine( _get_pecl_installed_for => undef );
    $mock_elevate->redefine(
        _read_stage_file => sub {
            return {
                pecl => {
                    cpanel => {
                        module_one => 1.2,
                        module_two => 2.2,
                    },

                }
            };
        }
    );

    clear_messages_seen();

    $pecl->_check_pecl_packages();

    message_seen_lines( 'WARN', <<'EOS' );
********************
WARNING: Missing pecl package(s) for /usr/local/cpanel/3rdparty/bin/pecl
Please reinstall these packages:
********************
- module_one
- module_two
#
EOS

    $mock_pecl->redefine(
        _get_pecl_installed_for => sub {
            return { module_one => 1.2 },;
        }
    );

    clear_messages_seen();
    $pecl->_check_pecl_packages();

    message_seen_lines( 'WARN', <<'EOS' );
********************
WARNING: Missing pecl package(s) for /usr/local/cpanel/3rdparty/bin/pecl
Please reinstall these packages:
********************
- module_two
#
EOS

}

done_testing;
