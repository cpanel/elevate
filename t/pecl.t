#!/usr/local/cpanel/3rdparty/bin/perl

# HARNESS-NO-STREAM

# cpanel - ./t/pecl.t                              Copyright 2022 cPanel, L.L.C.
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::Trap;

use Test::MockModule qw/strict/;

use Test::Cpanel::Policy;

use Test::MockFile;

use FindBin;

require $FindBin::Bin . q[/../elevate-cpanel];

$INC{'scripts/ElevateCpanel.pm'} = '__TEST__';

my $mock_elevate = Test::MockModule->new('scripts::ElevateCpanel');

my $mock_stage_file = Test::MockFile->file( scripts::ElevateCpanel::ELEVATE_STAGE_FILE() );

my $list_output;

my $mock_saferun = Test::MockModule->new('Cpanel::SafeRun::Simple');
$mock_saferun->redefine(
    saferunnoerror => sub {
        return $list_output;

    }
);

my $pecl_bin = Test::MockFile->file( '/my/pecl/bin', '', { mode => 0700 } );

is scripts::ElevateCpanel::_get_pecl_installed_for('/my/pecl/bin'), undef, '_get_pecl_installed_for - empty list';

$list_output = qq[(no packages installed from channel pecl.php.net)\n];

is scripts::ElevateCpanel::_get_pecl_installed_for('/my/pecl/bin'), undef, '_get_pecl_installed_for - no packages installed';

$list_output = <<'EOS';
Installed packages, channel pecl.php.net:
=========================================
Package Version State
imagick 3.5.1   stable
EOS

is scripts::ElevateCpanel::_get_pecl_installed_for('/my/pecl/bin'), {
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

is scripts::ElevateCpanel::_get_pecl_installed_for('/my/pecl/bin'), {
    ds      => q[1.4.0],
    imagick => q[3.5.1],
  },
  '_get_pecl_installed_for - ds + imagick';

{

    is scripts::ElevateCpanel::read_stage_file(), {}, "stage file is empty";

    $mock_elevate->redefine( _get_pecl_installed_for => sub { { module_one => 1.2 } } );

    scripts::ElevateCpanel::_store_pecl_for( '/whatever', 'cpanel' );

    is scripts::ElevateCpanel::read_stage_file(), { pecl => { cpanel => { module_one => 1.2 } } }, "stage file: store pecl for cpanel";

    $mock_elevate->redefine( _get_pecl_installed_for => sub { { xyz => 5.6 } } );
    scripts::ElevateCpanel::_store_pecl_for( '/whatever', 'ea-php80' );

    is scripts::ElevateCpanel::read_stage_file(), {
        pecl => {
            cpanel     => { module_one => 1.2 },
            'ea-php80' => { xyz        => 5.6 }
        }
      },
      "stage file: store pecl for cpanel & ea-php80";

}

{
    $mock_elevate->redefine( _get_pecl_installed_for => undef );
    $mock_elevate->redefine(
        read_stage_file => sub {
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

    trap {
        scripts::ElevateCpanel::check_pecl_packages();
    };

    is $trap->stdout, <<'EOS', 'Display the warning for two missing packages';
********************
WARNING: Missing pecl package(s) for /usr/local/cpanel/3rdparty/bin/pecl
Please reinstall these packages
********************
- module_one
- module_two
#
EOS

    $mock_elevate->redefine(
        _get_pecl_installed_for => sub {
            return { module_one => 1.2 },;
        }
    );

    trap {
        scripts::ElevateCpanel::check_pecl_packages();
    };

    is $trap->stdout, <<'EOS', 'Display the warning for one missing package';
********************
WARNING: Missing pecl package(s) for /usr/local/cpanel/3rdparty/bin/pecl
Please reinstall these packages
********************
- module_two
#
EOS

}

done_testing;
