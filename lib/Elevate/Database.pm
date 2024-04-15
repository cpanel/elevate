package Elevate::Database;

=encoding utf-8

=head1 NAME

Elevate::Database

Helper/Utility logic for database related tasks.

=cut

use cPstrict;

use Elevate::OS        ();
use Elevate::StageFile ();

use Cpanel::MysqlUtils::Version  ();
use Cpanel::MysqlUtils::Versions ();
use Cpanel::Pkgr                 ();

use Log::Log4perl qw(:easy);

use constant MYSQL_BIN => '/usr/sbin/mysqld';

use constant SUPPORTED_CPANEL_MYSQL_VERSIONS => qw{
  8.0
  10.3
  10.4
  10.5
  10.6
};

sub is_database_provided_by_cloudlinux ( $use_cache = 1 ) {

    if ($use_cache) {
        my $cloudlinux_database_installed = Elevate::StageFile::read_stage_file( 'cloudlinux_database_installed', '' );

        # cloudlinux_database_installed should only ever be 1 or 0 if it is set
        # by default, read_stage_file() will return '{}', but we are telling it to send back ''
        # if cloudlinux_database_installed is not currently set
        # This allows us to be sure that the cache is set when returning it
        return $cloudlinux_database_installed if length $cloudlinux_database_installed;
    }

    if ( !Elevate::OS::provides_mysql_governor() ) {
        Elevate::StageFile::update_stage_file( { cloudlinux_database_installed => 0 } );
        return 0;
    }

    # Returns undef if database is not provided by cloudlinux
    # Do not use cache since this could be the first call from --check
    # It might be different than what is cached when called from here
    my ( $db_type, $db_version ) = Elevate::Database::get_db_info_if_provided_by_cloudlinux(0);

    return 1 if $db_type && $db_version;
    return 0;
}

sub get_db_info_if_provided_by_cloudlinux ( $use_cache = 1 ) {

    if ($use_cache) {
        my $cloudlinux_database_info = Elevate::StageFile::read_stage_file( 'cloudlinux_database_info', '' );
        return ( $cloudlinux_database_info->{db_type}, $cloudlinux_database_info->{db_version} )
          if length $cloudlinux_database_info;
    }

    my $pkg = Cpanel::Pkgr::what_provides(MYSQL_BIN);

    my ( $db_type, $db_version ) = $pkg =~ m/^cl-(mysql|mariadb|percona)([0-9]+)-server$/i;

    # cache this data so we only need to query the package manager for it once
    my $cloudlinux_database_installed = ( $db_type && $db_version ) ? 1 : 0;
    Elevate::StageFile::update_stage_file( { cloudlinux_database_installed => $cloudlinux_database_installed } );

    if ($cloudlinux_database_installed) {
        Elevate::StageFile::update_stage_file(
            {
                cloudlinux_database_info => {
                    db_type    => lc $db_type,
                    db_version => $db_version,
                }
            }
        );
    }

    return ( $db_type, $db_version );
}

sub get_local_database_version () {

    my $version;

    eval {
        local $Cpanel::MysqlUtils::Version::USE_LOCAL_MYSQL = 1;
        $version = Cpanel::MysqlUtils::Version::uncached_mysqlversion();
    };
    if ( my $exception = $@ ) {
        WARN("Error encountered querying the version from the database server: $exception");

        # Load it from the configuration if we cannot get the version directly
        my $cpconf = Cpanel::Config::LoadCpConf::loadcpconf();
        $version = $cpconf->{'mysql-version'} // '';
    }

    return $version;
}

sub is_database_version_supported ($version) {

    return scalar grep { $version eq $_ } SUPPORTED_CPANEL_MYSQL_VERSIONS;
}

sub get_default_upgrade_version () {

    require Whostmgr::Mysql::Upgrade;

    return Whostmgr::Mysql::Upgrade::get_latest_available_version( version => get_local_database_version() );
}

sub get_database_type_name_from_version ($version) {
    return Cpanel::MariaDB::version_is_mariadb($version) ? 'MariaDB' : 'MySQL';
}

sub upgrade_database_server () {

    require Whostmgr::Mysql::Upgrade;

    my $upgrade_version = Elevate::StageFile::read_stage_file( 'mysql-version', '' );
    $upgrade_version ||= Elevate::Database::get_default_upgrade_version();

    my $upgrade_dbtype_name = Elevate::Database::get_database_type_name_from_version($upgrade_version);

    INFO("Beginning upgrade to $upgrade_dbtype_name $upgrade_version");

    my $failed_step = Whostmgr::Mysql::Upgrade::unattended_upgrade(
        {
            upgrade_type     => 'unattended_automatic',
            selected_version => $upgrade_version,
        }
    );

    if ($failed_step) {
        FATAL("FAILED to upgrade to $upgrade_dbtype_name $upgrade_version");
    }
    else {
        INFO("Finished upgrade to $upgrade_dbtype_name $upgrade_version");
    }

    return;
}

1;
