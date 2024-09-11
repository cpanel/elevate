package Elevate::Components::PostgreSQL;

=encoding utf-8

=head1 NAME

Elevate::Components::PostgreSQL

=head1 DESCRIPTION

Upgrades the system PostgreSQL instance.

This is considered to be a best-effort task: if something fails in an expected
way, it will emit errors and notify the user but will B<not> terminate the
ELevate process or otherwise cause it to be considered an overall failure.

=cut

use cPstrict;

use Simple::Accessor qw{service};

use parent qw{Elevate::Components::Base};

use Elevate::Constants        ();
use Elevate::Notify           ();
use Elevate::StageFile        ();
use Elevate::SystemctlService ();

use Cpanel::Pkgr              ();
use Cpanel::SafeRun::Object   ();
use Cpanel::Services::Enabled ();
use Whostmgr::Postgres        ();

use Log::Log4perl qw(:easy);

use File::Copy::Recursive ();
use File::Slurp           ();

sub _build_service ($self) {
    return Elevate::SystemctlService->new( name => 'postgresql' );
}

=head1 BEFORE LEAPP

=over

=cut

sub pre_distro_upgrade ($self) {
    if ( Cpanel::Pkgr::is_installed('postgresql-server') ) {
        $self->_store_postgresql_encoding_and_locale();
        $self->_disable_postgresql_service();
        $self->_backup_postgresql_datadir();
    }

    return;
}

=item _store_postgresql_encoding_and_locale

Fetch and record the encoding and immutable locale data of the C<template1>
database. This information is needed later to avoid RE-637. If this process
fails, something is probably wrong, but keep going anyway.

=cut

sub _store_postgresql_encoding_and_locale ($self) {

    return if $self->_gave_up_on_postgresql;    # won't hurt

    INFO("Fetching encoding and locale information from PostgreSQL.");

    my $is_active_prior = $self->service->is_active;

    # PostgreSQL needs to be up to get this information:
    $self->service->start();

    if ( $self->service->is_active ) {
        my $psql_sro = Cpanel::SafeRun::Object->new(
            program => '/usr/bin/psql',
            args    => [
                qw{-F | -At -U postgres -c},
                q{SELECT pg_encoding_to_char(encoding), datcollate, datctype FROM pg_catalog.pg_database WHERE datname = 'template1'},
            ],
        );

        if ( $psql_sro->CHILD_ERROR ) {
            WARN("The system instance of PostgreSQL did not return information about the encoding and locale of core databases.");
            WARN("ELevate will assume the system defaults and attempt an upgrade anyway.");
            return;
        }

        my $output = $psql_sro->stdout;
        chomp $output;

        my ( $encoding, $collation, $ctype ) = split /\|/, $output;
        Elevate::StageFile::update_stage_file(
            {
                postgresql_locale => {
                    encoding  => $encoding,
                    collation => $collation,
                    ctype     => $ctype,
                }
            }
        );

        $self->service->stop() unless $is_active_prior;
    }
    else {
        WARN("The system instance of PostgreSQL could not start to give information about the encoding and locale of core databases.");
        WARN("ELevate will assume the system defaults and attempt an upgrade anyway.");
    }

    return;
}

=item _disable_postgresql_service

Touches the file needed to get Service Manager to believe that PostgreSQL is
disabled. If the service is enabled, then upcp fails during the post-leapp
phase of the RpmDB component. Also doubles as the mechanism by which PostgreSQL
is disabled on a system where a step prior to the upgrade fails.

=cut

sub _disable_postgresql_service ($self) {

    if ( Cpanel::Services::Enabled::is_enabled('postgresql') ) {
        Elevate::StageFile::update_stage_file( { 're-enable_postgresql_in_sm' => 1 } );
        Cpanel::Services::Enabled::touch_disable_file('postgresql');
    }

    return;
}

=item _backup_postgresql_datadir

While the user should have backed up their system, as a convenience and assurance, take our own backup.

TODO: What happens if this runs out of disk space? Should we check first?

=cut

# XXX Is this really better than `cp -a $src $dst`? I hope nothing in there is owned by someone other than the postgres user...
sub _backup_postgresql_datadir ($self) {

    $self->service->stop() if $self->service->is_active;    # for safety

    my $pgsql_datadir_path        = Elevate::Constants::POSTGRESQL_SYSTEM_DATADIR;
    my $pgsql_datadir_backup_path = $pgsql_datadir_path . '_elevate_' . time() . '_' . $$;

    INFO("Backing up the system PostgreSQL data directory at $pgsql_datadir_path to $pgsql_datadir_backup_path.");

    # Set EUID/EGID to postgres (this is not security critical; it's just to retain correct ownership within copy):
    my ( $uid, $gid ) = ( scalar( getpwnam('postgres') ), scalar( getgrnam('postgres') ) );
    my $outcome = 0;
    {
        local ( $>, $) ) = ( $uid, "$gid $gid" );
        $outcome = File::Copy::Recursive::dircopy( $pgsql_datadir_path, $pgsql_datadir_backup_path );
    }

    if ( !$outcome ) {
        ERROR("The system encountered an error while trying to make a backup.");
        $self->_give_up_on_postgresql();
    }
    else {
        Elevate::Notify::add_final_notification( <<~"EOS" );
        ELevate backed up your system PostgreSQL data directory to $pgsql_datadir_backup_path
        prior to any modification or attempt to upgrade, in case the upgrade needs to be performed
        manually, or if old settings need to be referenced.
        EOS
    }

    return;
}

=back

=head1 AFTER LEAPP

=over

=cut

sub post_distro_upgrade ($self) {
    if ( Cpanel::Pkgr::is_installed('postgresql-server') ) {
        $self->_perform_config_workaround();
        $self->_perform_postgresql_upgrade();
        $self->_re_enable_service_if_needed();
        $self->_run_whostmgr_postgres_update_config();
    }

    return;
}

=item _perform_config_workaround

There is a bug with the EL8 postgresql-upgrade package, namely that the support
for the C<unix_socket_directories> configuration directive which was
back-ported from 9.3 into the 9.2 package for EL7 is not being applied to the
version of 9.2 being built to support the upgrade. For this reason, we need to
alter the existing F<postgresql.conf> file to comment out any
C<unix_socket_directories> directives and add a standard
C<unix_socket_directory> directive at the end instead.

=cut

sub _perform_config_workaround ($self) {
    return if $self->_gave_up_on_postgresql;

    my $pgconf_path = Elevate::Constants::POSTGRESQL_SYSTEM_DATADIR . '/postgresql.conf';
    return unless -e $pgconf_path;    # if postgresql.conf isn't there, there's nothing to work around

    my $pgconf = eval { File::Slurper::read_text($pgconf_path) };
    if ($@) {
        ERROR("Attempting to read $pgconf_path resulted in an error: $@");
        $self->_give_up_on_postgresql();
        return;
    }

    my $changed = 0;
    my @lines   = split "\n", $pgconf;
    foreach my $line (@lines) {
        next if $line =~ m/^\s*$/a;
        if ( $line =~ m/^\s*unix_socket_directories/ ) {
            $line    = "#$line";
            $changed = 1;
        }
    }

    if ($changed) {
        push @lines, "unix_socket_directory = '/var/run/postgresql'";

        INFO("Modifying $pgconf_path to work around a defect in the system's PostgreSQL upgrade package.");

        my $pgconf_altered = join "\n", @lines;
        eval { File::Slurper::write_text( $pgconf_path, $pgconf_altered ) };

        if ($@) {
            ERROR("Attempting to overwrite $pgconf_path resulted in an error: $@");
            $self->_give_up_on_postgresql();
        }
    }

    return;
}

=item _perform_postgresql_upgrade

Performs the upgrade using the EL-provided C<postgresql-setup --upgrade>
script. If encoding and locale data were collected in the pre distro upgrade phase, use
them here when provisioning the new cluster.

=cut

sub _perform_postgresql_upgrade ($self) {
    return if $self->_gave_up_on_postgresql;

    INFO("Installing PostgreSQL update package:");
    $self->dnf->install('postgresql-upgrade');

    my $opts = Elevate::StageFile::read_stage_file('postgresql_locale');
    my @args;
    push @args, "--encoding=$opts->{encoding}"    if $opts->{encoding};
    push @args, "--lc-collate=$opts->{collation}" if $opts->{collation};
    push @args, "--lc-ctype=$opts->{ctype}"       if $opts->{ctype};

    local $ENV{PGSETUP_INITDB_OPTIONS} = join ' ', @args if scalar @args > 0;

    INFO("Upgrading PostgreSQL data directory:");
    my $outcome = $self->ssystem( { keep_env => ( scalar @args > 0 ? 1 : 0 ) }, qw{/usr/bin/postgresql-setup --upgrade} );

    if ( $outcome == 0 ) {
        INFO("The PostgreSQL upgrade process was successful.");
        Elevate::Notify::add_final_notification( <<~EOS );
        ELevate successfully ran the upgrade procedure on the system instance of
        PostgreSQL. If no problems are reported with configuring the upgraded instance
        to work with cPanel, you should proceed with applying any relevant
        customizations to the configuration and authentication settings, since the
        upgrade process reset this information to system defaults.
        EOS
    }
    else {
        ERROR("The upgrade attempt of the system PostgreSQL instance failed. See the log files mentioned in the output of postgresql-setup for more information.");
        $self->_give_up_on_postgresql();
    }

    return;
}

=item _re_enable_service_if_needed

If the upgrade was successful, and we disabled the PostgreSQL service in Service Manager, re-enable the service now.

=cut

sub _re_enable_service_if_needed ($self) {
    return if $self->_gave_up_on_postgresql;    # keep disabled if there was a failure

    if ( Elevate::StageFile::read_stage_file( 're-enable_postgresql_in_sm', 0 ) ) {
        Cpanel::Services::Enabled::remove_disable_files('postgresql');
    }

    return;
}

=item _run_whostmgr_postgres_update_config

The upgrade completely reset the PostgreSQL configuration and authentication
methods, so this is the ideal time to invoke the WHM code to correctly
configure this for use with phpPgAdmin in cPanel.

This process happens I<after> the upgrade, so a failure here probably should
B<not> result in skipping following steps, if any are added in the future.

=cut

sub _run_whostmgr_postgres_update_config ($self) {
    return if $self->_gave_up_on_postgresql;

    INFO("Configuring PostgreSQL to work with cPanel's installation of phpPgAdmin.");
    $self->service->start();    # less noisy when it's online, but still works

    my ( $success, $msg ) = Whostmgr::Postgres::update_config();
    if ( !$success ) {
        ERROR("The system failed to update the PostgreSQL configuration: $msg");
        Elevate::Notify::add_final_notification( <<~EOS );
        ELevate could not configure the upgraded system PostgreSQL instance to work
        with cPanel. See the log for additional information. Once the issue has been
        addressed, perform this step manually using the "Postgres Config Install" area
        in WHM:

        https://go.cpanel.net/whmdocsConfigurePostgreSQL

        Do this before restoring any customizations to PostgreSQL configuration or
        authentication files, since performing this action resets these to cPanel
        defaults.
        EOS
    }

    return;
}

=back

=head1 UTILITY METHODS

=over

=item _give_up_on_postgresql

Invoke when all subsequent steps of the PostgreSQL upgrade should be skipped due to a failure.

=cut

sub _give_up_on_postgresql ($self) {
    ERROR('Skipping attempt to upgrade the system instance of PostgreSQL.');
    Elevate::StageFile::update_stage_file( { postgresql_give_up => 1 } );
    Elevate::Notify::add_final_notification( <<~EOS );
    The process of upgrading the system instance of PostgreSQL failed. The
    PostgreSQL service has been disabled in the Service Manager in WHM:

    https://go.cpanel.net/whmdocsServiceManager

    If you do not have cPanel users who use PostgreSQL or otherwise do not use it,
    you do not have to take any action. Otherwise, see the ELevate logs for further
    information.
    EOS
    return;
}

=item _gave_up_on_postgresql

=item _given_up_on_postgresql

Returns true if an error has prompted us to skip the upgrade.

=cut

sub _gave_up_on_postgresql ($self) {
    return Elevate::StageFile::read_stage_file( 'postgresql_give_up', 0 );
}

# alias
sub _given_up_on_postgresql {
    goto &_gave_up_on_postgresql;
}

=back

=cut

1;
