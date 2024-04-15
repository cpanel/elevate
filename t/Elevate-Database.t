#!/usr/local/cpanel/3rdparty/bin/perl

use cPstrict;

use FindBin;

use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/lib";
use Test::Elevate;
use Test::Elevate::OS;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test::MockModule qw{strict};

use Elevate::Database ();
use Elevate::OS       ();

my $stash = [];

my $cloudlinux_database_installed;
my $cloudlinux_database_info;

my $mock_stagefile = Test::MockModule->new('Elevate::StageFile');
$mock_stagefile->redefine(
    read_stage_file => sub ( $key, $default = undef ) {
        return $cloudlinux_database_installed if $key eq 'cloudlinux_database_installed';
        return $cloudlinux_database_info      if $key eq 'cloudlinux_database_info';
        return $default;
    },
    update_stage_file => sub {
        my $update = shift;
        push @$stash, $update;
        return;
    },
);

{
    note 'Test is_database_provided_by_cloudlinux() behavior';

    set_os_to('cent');

    is(
        Elevate::Database::is_database_provided_by_cloudlinux(),
        0,
        'is_database_provided_by_cloudlinux() returns 0 when the OS is CentOS'
    );

    is( $stash, [ { cloudlinux_database_installed => 0, } ], 'The expected data is stashed' );

    $cloudlinux_database_installed = 42;
    $stash                         = [];

    is(
        Elevate::Database::is_database_provided_by_cloudlinux(),
        42,
        'is_database_provided_by_cloudlinux() uses the cache when it exists'
    );

    is( $stash, [], 'No data is stashed when the cache is used' );

    is(
        Elevate::Database::is_database_provided_by_cloudlinux(0),
        0,
        'is_database_provided_by_cloudlinux() does not use the cache when use_cache is disabled'
    );

    is( $stash, [ { cloudlinux_database_installed => 0, } ], 'The expected data is stashed' );

    set_os_to('cloud');

    local *Elevate::Database::get_db_info_if_provided_by_cloudlinux = sub { return ( 1, 1 ); };

    diag explain $Elevate::OS::OS;
    is(
        Elevate::Database::is_database_provided_by_cloudlinux(0),
        1,
        'is_database_provided_by_cloudlinux() returns 1 when CL MySQL is in use'
    );

    local *Elevate::Database::get_db_info_if_provided_by_cloudlinux = sub { return ( 0, 0 ); };

    is(
        Elevate::Database::is_database_provided_by_cloudlinux(0),
        0,
        'is_database_provided_by_cloudlinux() returns 0 when CL MySQL is NOT in use'
    );
}

{
    note 'Test get_db_info_if_provided_by_cloudlinux() behavior';

    my $pkg = 'foo';

    my $mock_cpanel_pkgr = Test::MockModule->new('Cpanel::Pkgr');
    $mock_cpanel_pkgr->redefine(
        what_provides => sub { return $pkg; },
    );

    $stash = [];

    is(
        Elevate::Database::get_db_info_if_provided_by_cloudlinux(),
        undef,
        'get_db_info_if_provided_by_cloudlinux() return undef when MySQL is not provided by CL'
    );

    is( $stash, [ { cloudlinux_database_installed => 0, } ], 'The expected things are stashed' );

    $stash                    = [];
    $cloudlinux_database_info = {
        db_type    => 'foo',
        db_version => 42,
    };

    my @expected = ( 'foo', 42 );
    my @db_info  = Elevate::Database::get_db_info_if_provided_by_cloudlinux();
    is(
        @db_info,
        @expected,
        'The expected data is returned when the cache is used',
    );

    is( $stash, [], 'The stash is not updated when the cache is used' );

    is(
        Elevate::Database::get_db_info_if_provided_by_cloudlinux(0),
        undef,
        'The cache is ignored when use_cache is set to 0',
    );

    is( $stash, [ { cloudlinux_database_installed => 0, } ], 'The expected things are stashed' );

    $stash = [];
    $pkg   = 'cl-MySQL24-server';

    @expected = ( 'mysql', 24 );
    @db_info  = Elevate::Database::get_db_info_if_provided_by_cloudlinux(0);
    is(
        @db_info,
        @expected,
        'get_db_info_if_provided_by_cloudlinux() returns the expected data when CL MySQL is in use'
    );

    is(
        $stash,
        [
            {
                cloudlinux_database_installed => 1,
            },
            {
                cloudlinux_database_info => {
                    db_type    => 'mysql',
                    db_version => 24,
                },
            },
        ],
        'The expected things are stashed',
    );
}

{
    note 'Test get_local_database_version() behavior';

    my $mysql_version        = 42;
    my $mysql_version_config = 52;

    my $mock_version = Test::MockModule->new('Cpanel::MysqlUtils::Version');
    $mock_version->redefine(
        uncached_mysqlversion => sub {
            return $mysql_version if $mysql_version;
            die "MYSQL_VERSION_FAIL";
        },
    );

    my $mock_cpconf = Test::MockModule->new('Cpanel::Config::LoadCpConf');
    $mock_cpconf->redefine(
        loadcpconf => sub { return { 'mysql-version' => $mysql_version_config }; },
    );

    # Happy path test
    is(
        Elevate::Database::get_local_database_version(),
        $mysql_version,
        'Returns result of querying mysql version'
    );
    no_messages_seen();

    # Test regular call failing & getting mysql version from the config
    $mysql_version = 0;
    is(
        Elevate::Database::get_local_database_version(),
        $mysql_version_config,
        'Returns result of getting mysql version from the config'
    );
    message_seen( 'WARN', qr/MYSQL_VERSION_FAIL/ );
}

{
    note 'Test is_database_version_supported() behavior';

    my @should_pass = qw(8.0 10.3 10.4 10.5 10.6);
    my @should_fail = qw(5.0 5.5 5.7 -2 83 3.1415);

    foreach my $pass_version (@should_pass) {
        ok( Elevate::Database::is_database_version_supported($pass_version), "$pass_version is supported" );
    }

    foreach my $fail_version (@should_fail) {
        ok( !Elevate::Database::is_database_version_supported($fail_version), "$fail_version is NOT supported" );
    }
}

done_testing();
