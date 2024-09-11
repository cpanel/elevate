#!/usr/local/cpanel/3rdparty/bin/perl
package test::cpev::components;

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use cPstrict;

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockModule qw/strict/;
use Test::MockFile   qw/strict/;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use constant PROFILE_FILE => Elevate::Components::DatabaseUpgrade::MYSQL_PROFILE_FILE;

my $db_upgrade = bless {}, 'Elevate::Components::DatabaseUpgrade';

{
    note('Checking pre_distro_upgrade');

    my $mock_elevate_database = Test::MockModule->new('Elevate::Database');
    $mock_elevate_database->redefine(
        'is_database_provided_by_cloudlinux' => 0,
        'is_database_version_supported'      => 0,
        'upgrade_database_server'            => 0,
        'get_local_database_version'         => '5.7',
    );

    my $mock_db_upgrade = Test::MockModule->new('Elevate::Components::DatabaseUpgrade');

    my @_ensure_localhost_mysql_profile_is_active_params;
    $mock_db_upgrade->redefine(
        '_ensure_localhost_mysql_profile_is_active',
        sub {
            ( undef, @_ensure_localhost_mysql_profile_is_active_params ) = @_;
            return;
        }
    );

    $db_upgrade->pre_distro_upgrade();
    is \@_ensure_localhost_mysql_profile_is_active_params, [1], '_ensure_localhost_mysql_profile_is_active was called with correct params';

    clear_messages_seen();
}

{
    note('Checking post_distro_upgrade');

    my @cmds;
    my @stdout;
    my $mock_db_upgrade = Test::MockModule->new('Elevate::Components::DatabaseUpgrade');
    $mock_db_upgrade->redefine(
        'ssystem_capture_output',
        sub ( $, @args ) {
            push @cmds, [@args];
            return { status => 0, stdout => \@stdout, stderr => [] };
        }
    );

    my $mock_profile_file = Test::MockFile->file(PROFILE_FILE);
    $db_upgrade->post_distro_upgrade();
    no_messages_seen();

    $mock_profile_file->contents('original-db-profile-name');
    like(
        dies { $db_upgrade->post_distro_upgrade() },
        qr/Unable to reactivate/,
        'Died as expected when profile activation done is not seen'
    );

    message_seen( 'INFO', 'Reactivating "original-db-profile-name" MySQL profile' );
    is \@cmds, [
        [
            '/usr/local/cpanel/scripts/manage_mysql_profiles',
            '--activate',
            'original-db-profile-name'
        ]
      ],
      'Expected "manage_mysql_profiles" command was executed';
    @cmds = ();

    no_messages_seen();
    ok -e PROFILE_FILE, 'profile file still exists after failed reactivation';

    @stdout = ('MySQL profile activation done');
    $db_upgrade->post_distro_upgrade();
    message_seen( 'INFO', 'Reactivating "original-db-profile-name" MySQL profile' );
    is \@cmds, [
        [
            '/usr/local/cpanel/scripts/manage_mysql_profiles',
            '--activate',
            'original-db-profile-name'
        ]
      ],
      'Expected "manage_mysql_profiles" command was executed';
    @cmds = ();
    no_messages_seen();
    ok !-e PROFILE_FILE, 'profile file removed after successful reactivation';

    clear_messages_seen();
}

{
    note('Checking _ensure_localhost_mysql_profile_is_active');

    my $saved_db_file_mock = Test::MockFile->file('/var/cpanel/elevate-mysql-profile');
    my $mock_mysqlutils    = Test::MockModule->new('Cpanel::MysqlUtils::MyCnf::Basic');
    $mock_mysqlutils->redefine( 'is_local_mysql', 1 );

    my $instantiated_pm = 0;
    my $mock_pm         = Test::MockModule->new('Cpanel::MysqlUtils::RemoteMySQL::ProfileManager');
    $mock_pm->redefine( 'new', sub { $instantiated_pm = 1; return bless {}, 'Cpanel::MysqlUtils::RemoteMySQL::ProfileManager' } );

    $db_upgrade->_ensure_localhost_mysql_profile_is_active(0);
    is $instantiated_pm, 0, 'ProfileManager instance not created when is_local_mysql returns true';

    $mock_mysqlutils->redefine( 'is_local_mysql', 0 );
    $mock_pm->redefine(
        'validate_profile', sub { die 'foo' },
        'read_profiles',
        sub {
            return {
                'localhost' => {
                    'mysql_port' => '3306',
                    'mysql_pass' => 'hunter2',
                    'mysql_host' => 'localhost',
                    'mysql_user' => 'azurediamond',
                    'setup_via'  => 'Auto-Migrated active profile',
                    'active'     => 0,
                },
                'remote' => {
                    'mysql_port' => '69420',
                    'mysql_pass' => 'NHTSA_R00lz',
                    'mysql_host' => 'test.test',
                    'mysql_user' => 'crash_test_dummy',
                    'setup_via'  => "The People's Quality Front",
                    'active'     => 1
                },
            };
        },
    );

    like(
        dies { $db_upgrade->_ensure_localhost_mysql_profile_is_active(0) },
        qr/Unable to generate/,
        'Died as expected when profile validation fails and should_create_localhost_profile is false'
    );

    my $mock_db_upgrade = Test::MockModule->new('Elevate::Components::DatabaseUpgrade');
    $mock_db_upgrade->redefine( '_activate_localhost_profile', sub { die 'moo' } );

    $mock_pm->redefine( 'validate_profile', 1 );
    like(
        dies { $db_upgrade->_ensure_localhost_mysql_profile_is_active(0) },
        qr/Unable to generate/,
        'Died as expected when _activate_localhost_profile fails and should_create_localhost_profile is false'
    );

    $mock_pm->redefine( 'validate_profile', sub { die "whugg" } );
    my $created_new_localhost_profile = 0;
    $mock_db_upgrade->redefine( '_create_new_localhost_profile', sub { $created_new_localhost_profile = 1 } );
    eval { $db_upgrade->_ensure_localhost_mysql_profile_is_active(1) };
    is $created_new_localhost_profile, 1, '_create_new_localhost_profile() was called when existing profile failed to validate/activate';
    message_seen( 'INFO', qr{Saving the currently active MySQL Profile \(remote\) to /var/cpanel/elevate-mysql-profile} );
    message_seen( 'INFO', qr/Attempting to create new localhost MySQL profile/ );

    clear_messages_seen();
}

{
    note('Checking _set_local_mysql_root_password');

    my @cmds;
    my $stdout       = '{"metadata":{"reason":"OK","version":1,"result":1,"command":"set_local_mysql_root_password"},"data":{"configs_updated":1,"profile_updated":1,"password_reset":1}}';
    my $mock_saferun = Test::MockModule->new('Cpanel::SafeRun::Simple');
    $mock_saferun->redefine( 'saferunnoerror', sub { push @cmds, \@_; return $stdout } );

    ok lives { $db_upgrade->_set_local_mysql_root_password('F00b4r!@#%$%') }, '_set_local_mysql_root_password with successful api call lives';
    message_seen( 'INFO', qr/Resetting password for local root database user/ );

    is \@cmds, [
        [
            '/bin/sh',
            '-c',
            '/usr/local/cpanel/bin/whmapi1 --output=json set_local_mysql_root_password password=\'F00b4r%21%40%23%25%24%25\''
        ]
      ],
      'Exected saferun command was run';

    $stdout = '{"metadata":{"version":1,"reason":"Failed to perform “set_root_mysql_password” action. 1 error occurred.","command":"set_local_mysql_root_password","error_count":1,"errors":["(XID kv75bw) The given password is too weak. Please enter a password with a strength rating of 65 or higher."],"result":0}}';
    like(
        dies { $db_upgrade->_set_local_mysql_root_password('F00b4') },
        qr/The following errors occurred/,
        'Handles errors from JSON API result correctly',
    );

    clear_messages_seen();

}

{
    note('Checking _activate_localhost_profile');

    my @cmds;
    my @stdout;
    my $mock_db_upgrade = Test::MockModule->new('Elevate::Components::DatabaseUpgrade');
    $mock_db_upgrade->redefine(
        'ssystem_capture_output',
        sub ( $, @args ) {
            push @cmds, [@args];
            return { status => 0, stdout => \@stdout, stderr => [] };
        }
    );

    like(
        dies { $db_upgrade->_activate_localhost_profile() },
        qr/Unable to activate/,
        'Died as expected when profile activation string not present in manage_mysql_profiles output',
    );

    message_seen( 'INFO', qr/Activating.*MySQL profile/ );
    is \@cmds, [
        [
            '/usr/local/cpanel/scripts/manage_mysql_profiles',
            '--activate',
            'localhost'
        ]
      ],
      'Expected manage_mysql_profiles command was executed';
    @cmds = ();

    @stdout = ('MySQL profile activation done');
    ok lives { $db_upgrade->_activate_localhost_profile() }, ' _activate_localhost_profile() did not die on successful activation call';

    clear_messages_seen();
}

{
    note('Checking _create_new_localhost_profile');

    my $mock_mysqlutils = Test::MockModule->new('Cpanel::MysqlUtils::MyCnf::Basic');
    $mock_mysqlutils->redefine( 'getmydbport', 3306 );

    my $mock_profile_file = Test::MockFile->file(PROFILE_FILE);
    my ( @create_profile_params, $save_changes_to_disk_called, $create_profile_called );
    my $mock_pm = Test::MockModule->new('Cpanel::MysqlUtils::RemoteMySQL::ProfileManager');
    $mock_pm->redefine(
        'new'                  => sub { return bless {}, 'Cpanel::MysqlUtils::RemoteMySQL::ProfileManager' },
        'create_profile'       => sub { $create_profile_called = 1; return 1 },
        'get_active_profile'   => sub { return 'cow-goes-moo' },
        'save_changes_to_disk' => sub { $save_changes_to_disk_called = 1 },
    );
    my $profile_manager = Cpanel::MysqlUtils::RemoteMySQL::ProfileManager->new();

    my ( $called_set_local_mysql_root_password, $called_activate_localhost_profile );
    my $mock_db_upgrade = Test::MockModule->new('Elevate::Components::DatabaseUpgrade');
    $mock_db_upgrade->redefine( '_set_local_mysql_root_password' => sub { $called_set_local_mysql_root_password = 1; return 1 } );
    $mock_db_upgrade->redefine( '_activate_localhost_profile', sub { $called_activate_localhost_profile = 1 } );

    ok lives { $db_upgrade->_create_new_localhost_profile($profile_manager) }, '_create_new_localhost_profile did not die';
    is $called_set_local_mysql_root_password, 1, '_set_local_mysql_root_password was called';
    is $called_activate_localhost_profile,    1, '_activate_localhost_profile was called';
    is $save_changes_to_disk_called,          1, 'ProfileManager->save_changes_to_disk() was called';
    is $create_profile_called,                1, 'ProfileManager->create_profile() was called';

    no_messages_seen();

}

done_testing();
