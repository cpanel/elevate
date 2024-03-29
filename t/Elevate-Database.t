#!/usr/local/cpanel/3rdparty/bin/perl

use cPstrict;

use FindBin;

use lib "$FindBin::Bin/../lib";

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test::MockModule qw{strict};

use Elevate::Database ();
use Elevate::OS       ();

my $stash = [];

my $cloudlinux_database_installed;
my $cloudlinux_database_info;
my $os;

my $mock_elevate_os = Test::MockModule->new('Elevate::OS');
$mock_elevate_os->redefine(
    _set_cache => 0,
);

{
    note 'Test is_database_provided_by_cloudlinux() behavior';

    local $Elevate::OS::OS = undef;
    $os = 'CentOS7';

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

    local $Elevate::OS::OS = undef;
    $os = 'CloudLinux7';

    local *Elevate::Database::get_db_info_if_provided_by_cloudlinux = sub { return ( 1, 1 ); };

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

done_testing();

# ------------------------------ #

package cpev;

sub read_stage_file ( $key, $default = undef ) {
    return $os                            if $key eq 'upgrade_from';
    return $cloudlinux_database_installed if $key eq 'cloudlinux_database_installed';
    return $cloudlinux_database_info      if $key eq 'cloudlinux_database_info';
    return $default;
}

sub update_stage_file {
    my $update = shift;
    push @$stash, $update;
    return;
}
