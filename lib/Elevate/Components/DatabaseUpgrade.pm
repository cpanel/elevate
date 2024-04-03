package Elevate::Components::DatabaseUpgrade;

=encoding utf-8

=head1 NAME

Elevate::Components::DatabaseUpgrade

Handle auto-upgrades for outdated versions of MySQL/MariaDB

=cut

use cPstrict;

use Elevate::Database ();

use parent qw{Elevate::Components::Base};

use Log::Log4perl qw(:easy);

sub pre_leapp ($self) {

    # We don't auto-upgrade the database if provided by cloudlinux
    return if Elevate::Database::is_database_provided_by_cloudlinux();

    # If the database version is supported on the new OS version, then no need to upgrade
    return if Elevate::Database::is_database_version_supported( Elevate::Database::get_local_database_version() );

    Elevate::Database::upgrade_database_server();

    return;
}

sub post_leapp ($self) {

    # Nothing to do
    return;
}

1;
