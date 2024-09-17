#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

package test::cpev::PostgreSQL;

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockModule qw/strict/;
use Test::MockFile;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;

use Elevate::Constants ();

use constant PRE_LEAPP_METHODS => [
    qw(
      _store_postgresql_encoding_and_locale
      _disable_postgresql_service
      _backup_postgresql_datadir
    )
];

use constant POST_LEAPP_METHODS => [
    qw(
      _perform_config_workaround
      _perform_postgresql_upgrade
      _re_enable_service_if_needed
      _run_whostmgr_postgres_update_config
    )
];

my $comp_pgsql = bless {}, 'Elevate::Components::PostgreSQL';

my $mock_pgsql     = Test::MockModule->new('Elevate::Components::PostgreSQL');
my $mock_stagefile = Test::MockModule->new('Elevate::StageFile');

my $mock_pkgr = Test::MockModule->new('Cpanel::Pkgr');
my $installed;
$mock_pkgr->redefine(
    is_installed => sub { return $_[0] eq 'postgresql-server' ? $installed : $mock_pkgr->original('postgresql-server')->(@_) },
);

{
    note "Checking pre_distro_upgrade";

    $installed = 0;
    $mock_pgsql->redefine(
        map {
            $_ => sub { die "shouldn't run" }
        } PRE_LEAPP_METHODS->@*
    );
    ok( lives { $comp_pgsql->pre_distro_upgrade() }, "Nothing is run if postgresql-server is not installed" );
    $mock_pgsql->unmock( PRE_LEAPP_METHODS->@* );

    $installed = 1;
}

{
    note "Checking post_distro_upgrade";

    $installed = 0;
    $mock_pgsql->redefine(
        map {
            $_ => sub { die "shouldn't run" }
        } POST_LEAPP_METHODS->@*
    );
    ok( lives { $comp_pgsql->post_distro_upgrade() }, "Nothing is run if postgresql-server is not installed" );
    $mock_pgsql->unmock( POST_LEAPP_METHODS->@* );

    $installed = 1;

    my $mock_pg_conf = Test::MockFile->file( Elevate::Constants::POSTGRESQL_SYSTEM_DATADIR . '/postgresql.conf' );

    $mock_pg_conf->contents("no matches");
    $comp_pgsql->_perform_config_workaround();
    is( $mock_pg_conf->contents, "no matches", "Nothing changes with postgresql.conf if no unix_socket_directories" );

    $mock_pg_conf->contents("unix_socket_directories = '/var/run/postgresql, /tmp'");
    $comp_pgsql->_perform_config_workaround();
    is( $mock_pg_conf->contents, "#unix_socket_directories = '/var/run/postgresql, /tmp'\nunix_socket_directory = '/var/run/postgresql'", "Fix applied if unix_socket_directories is present" );
}

done_testing();
