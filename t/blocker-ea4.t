#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

package test::cpev::blockers;

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockFile 0.032;
use Test::MockModule qw/strict/;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;

use Cpanel::JSON;

require $FindBin::Bin . '/../elevate-cpanel';

my $blockers = cpev->new->blockers;
my $ea4      = $blockers->_get_blocker_for('EA4');

my $mock_ea4 = Test::MockModule->new('Elevate::Blockers::EA4');

my $mock_elevate_ea4 = Test::MockModule->new('Elevate::EA4');

{
    my $mock_isea4 = Test::MockFile->file( '/etc/cpanel/ea4/is_ea4' => 1 );
    my $type       = '';

    $mock_elevate_ea4->redefine( backup => sub { return; } );
    my $mock_stagefile = Test::MockModule->new('Elevate::StageFile');
    $mock_stagefile->redefine(
        _read_stage_file => sub {
            return {
                ea4 => {
                    dropped_pkgs => {
                        'ea4-bad-pkg' => $type,
                    },
                },
            };
        }
    );

    # only testing the blocking case

    for my $os ( 'cent', 'cloud' ) {
        set_os_to($os);

        my $expected_target_os = $os eq 'cent' ? 'AlmaLinux 8' : 'CloudLinux 8';
        like(
            $ea4->_blocker_ea4_profile(),
            {
                id  => q[Elevate::Blockers::EA4::_blocker_ea4_profile],
                msg => <<~"EOS",
        One or more EasyApache 4 package(s) are not compatible with $expected_target_os.
        Please remove these packages before continuing the update.
        - ea4-bad-pkg
        EOS

            },
            'blocks when EA4 has an incompatible package'
        );

        my $target_os = $os eq 'cent' ? 'AlmaLinux 8' : 'CloudLinux 8';
        ea_info_check($target_os);
        message_seen( WARN => <<"EOS");
*** Elevation Blocker detected: ***
One or more EasyApache 4 package(s) are not compatible with $target_os.
Please remove these packages before continuing the update.
- ea4-bad-pkg

EOS

    }

    no_messages_seen();

}

{
    $mock_elevate_ea4->redefine( backup => sub { return; } );

    for my $os ( 'cent', 'cloud' ) {
        set_os_to($os);

        my $target_os = $os eq 'cent' ? 'AlmaLinux 8' : 'CloudLinux 8';

        ok !$ea4->_blocker_ea4_profile(), "no ea4 blockers without an ea4 profile to backup";
        ea_info_check($target_os);

        my $stage_file = Test::MockFile->file( Elevate::StageFile::ELEVATE_STAGE_FILE() );

        my $stage_ea4 = {
            profile => '/some/file.not.used.there',
        };

        my $update_stage_file_data = {};

        my $mock_stagefile = Test::MockModule->new('Elevate::StageFile');
        $mock_stagefile->redefine(
            _read_stage_file => sub {
                return { ea4 => $stage_ea4 };
            },
            update_stage_file => sub ($data) {
                $update_stage_file_data = $data;
            },
        );

        ok( !$ea4->_blocker_ea4_profile(), "no ea4 blockers: profile without any dropped_pkgs" );

        ea_info_check($target_os);

        $stage_ea4->{'dropped_pkgs'} = {
            "ea-bar" => "exp",
            "ea-baz" => "exp",
        };
        ok( !$ea4->_blocker_ea4_profile(), "no ea4 blockers: profile with dropped_pkgs: exp only" );
        ea_info_check($target_os);

        $stage_ea4->{'dropped_pkgs'} = {
            "pkg1"   => "reg",
            "ea-baz" => "exp",
            "pkg3"   => "reg",
            "pkg4"   => "whatever",
        };

        ok my $blocker = $ea4->_blocker_ea4_profile(), "_blocker_ea4_profile ";
        ea_info_check($target_os);

        message_seen( 'WARN' => qr[Elevation Blocker detected] );

        like $blocker, object {
            prop blessed => 'cpev::Blocker';

            field id => q[Elevate::Blockers::EA4::_blocker_ea4_profile];
            field msg => qq[One or more EasyApache 4 package(s) are not compatible with $target_os.
Please remove these packages before continuing the update.
- pkg1
- pkg3
- pkg4
];

            end();
        }, "blocker with expected error" or diag explain $blocker;

        $mock_ea4->redefine(
            _php_version_is_in_use          => 1,
            _php_is_provided_by_imunify_360 => 0,
        );

        $stage_ea4->{'dropped_pkgs'} = {
            pkg1       => 'exp',
            pkg2       => 'reg',
            'ea-php42' => 'reg',
        };

        ok $blocker = $ea4->_blocker_ea4_profile(), "_blocker_ea4_profile ";
        ea_info_check($target_os);

        message_seen( 'WARN' => qr[Elevation Blocker detected] );

        like $blocker, object {
            prop blessed => 'cpev::Blocker';

            field id => q[Elevate::Blockers::EA4::_blocker_ea4_profile];
            field msg => qq[One or more EasyApache 4 package(s) are not compatible with $target_os.
Please remove these packages before continuing the update.
- ea-php42
- pkg2
];

            end();
        }, "blocker with expected error when dropped ea-php package is in use"
          or diag explain $blocker;

        $mock_ea4->redefine(
            _php_version_is_in_use          => 0,
            _php_is_provided_by_imunify_360 => 0,
        );

        $stage_ea4->{'dropped_pkgs'} = {
            'ea-php42' => 'reg',
        };

        ok !$ea4->_blocker_ea4_profile(), 'No blocker when dropped package is an ea-php version that is not in use';
        ea_info_check($target_os);

        $mock_ea4->redefine(
            _php_version_is_in_use          => 0,
            _php_is_provided_by_imunify_360 => 1,
        );

        ok !$ea4->_blocker_ea4_profile(), 'No blocker when dropped package is an ea-php version that is in use but provided by Imunify 360';
        ea_info_check($target_os);

        is(
            $update_stage_file_data,
            {},
            'No ea-php packages need to be installed for Imunify 360 when the PHP version is not in use'
        ) or diag explain $update_stage_file_data;

        $mock_ea4->redefine(
            _php_version_is_in_use          => 1,
            _php_is_provided_by_imunify_360 => 1,
        );

        ok !$ea4->_blocker_ea4_profile(), 'No blocker when dropped package is an ea-php version that is in use but provided by Imunify 360';
        ea_info_check($target_os);

        is(
            $update_stage_file_data,
            {
                ea4_imunify_packages => ['ea-php42'],
            },
            'No ea-php packages need to be installed for Imunify 360 when the PHP version is not in use'
        ) or diag explain $update_stage_file_data;

        $stage_ea4 = {};
    }

    no_messages_seen();
}

{
    note 'Testing _php_version_is_in_use()';

    $mock_ea4->unmock('_php_version_is_in_use');

    $mock_ea4->redefine(
        _get_php_versions_in_use => sub ($self) {
            return {
                api_fail => 1,
            };
        },
    );

    is( $ea4->_php_version_is_in_use('ea-php42'), 1, 'The version is always considered to be in use when the underlying API call fails' );

    my $is_installed = 1;
    $mock_ea4->redefine(
        _get_php_versions_in_use => sub ($self) {
            return {
                'ea-php42' => $is_installed,
            };
        },
    );

    is( $ea4->_php_version_is_in_use('ea-php42'), 1, 'Returns 1 when the version of PHP is in use' );

    $is_installed = 0;

    is( $ea4->_php_version_is_in_use('ea-php42'), 0, 'Returns 0 when the version of PHP is NOT in use' );
}

{
    note 'Testing _get_php_versions_in_use';

    $mock_ea4->unmock('_get_php_versions_in_use');

    my $mock_result;
    my @saferun_calls;
    my $mock_saferunnoerror = Test::MockModule->new('Cpanel::SafeRun::Simple');
    $mock_saferunnoerror->redefine(
        saferunnoerror => sub {
            @saferun_calls = @_;
            return $mock_result;
        },
    );

    is( $ea4->_get_php_versions_in_use(), { api_fail => 1, }, 'api_fail is set when the API call does not return valid JSON' );

    is( \@saferun_calls, [qw{/usr/local/cpanel/bin/whmapi1 --output=json php_get_vhost_versions}], 'The expected API call is made' );

    message_seen( WARN => qr/Unable to determine if PHP versions that will be dropped are in use/ );

    $ea4->_get_php_versions_in_use();
    is( \@saferun_calls, [qw{/usr/local/cpanel/bin/whmapi1 --output=json php_get_vhost_versions}], 'The API call is only made one time' );

    local $Elevate::Blockers::EA4::php_versions_in_use = undef;
    $mock_result = {
        metadata => {
            result => 1,
        },
        data => {
            versions => [
                {
                    version => 'ea-php1',
                },
                {
                    version => 'ea-php2',
                },
                {
                    version => 'ea-php3',
                },
            ],
        },
    };

    $mock_result = Cpanel::JSON::Dump($mock_result);

    is(
        $ea4->_get_php_versions_in_use(),
        {
            'ea-php1' => 1,
            'ea-php2' => 1,
            'ea-php3' => 1,
        },
        'The expected result is returned when the API call succeeds',
    );

    no_messages_seen();
}

sub ea_info_check ($os) {
    message_seen( 'INFO' => "Checking EasyApache profile compatibility with $os." );
}

done_testing();
