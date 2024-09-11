package Elevate::Components::CCS;

=encoding utf-8

=head1 NAME

Elevate::Components::CCS

pre_distro_upgrade: Export CCS data to a root owned backup directory and remove CCS
           package

post_distro_upgrade: Install CCS package and import the backups taken during pre_distro_upgrade

=cut

use cPstrict;

use Try::Tiny;

use File::Path ();
use File::Copy ();

use Cpanel::Autodie       ();
use Cpanel::Config::Users ();
use Cpanel::JSON          ();
use Cpanel::Pkgr          ();

use Elevate::Notify    ();
use Elevate::StageFile ();

use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

use constant CCS_PACKAGE        => 'cpanel-ccs-calendarserver';
use constant ZPUSH_PACKAGE      => 'cpanel-z-push';
use constant EXPORT_DIR         => '/var/cpanel/elevate_ccs_export';
use constant CCS_RESTART_SCRIPT => '/usr/local/cpanel/scripts/restartsrv_cpanel_ccs';
use constant TASK_QUEUE_SCRIPT  => '/usr/local/cpanel/bin/servers_queue';

use constant DUMP_TYPES => (
    calendars => 'ics',
    contacts  => 'vcard',
);

sub pre_distro_upgrade ($self) {
    my $ccs_installed = Cpanel::Pkgr::is_installed(CCS_PACKAGE);
    Elevate::StageFile::update_stage_file( { ccs_installed => $ccs_installed } );
    return unless $ccs_installed;

    $self->_load_ccs_modules();

    $self->run_once('export_ccs_data');
    $self->remove_ccs_and_dependencies();

    # Removing the PKG will leave this directory in place
    # This results in PostGreSQL/CCS failing to start after leapp completes
    $self->clean_up_pkg_cruft();

    return;
}

sub clean_up_pkg_cruft ($self) {
    $self->remove_cpanel_ccs_home_directory();
    return;
}

=head1 remove_cpanel_ccs_home_directory

Removing the package removes the `cpanel-ccs` user, but leaves behind
the data in the home directory.  This results in the service failing
to start after the elevation has completed

=cut

sub remove_cpanel_ccs_home_directory ($self) {
    File::Path::remove_tree('/opt/cpanel-ccs') if -d '/opt/cpanel-ccs';
    return;
}

sub remove_ccs_and_dependencies ($self) {

    my $zpush_installed = Cpanel::Pkgr::is_installed(ZPUSH_PACKAGE);
    Elevate::StageFile::update_stage_file( { zpush_installed => $zpush_installed } );

    my @ccs_dependencies;
    push @ccs_dependencies, ZPUSH_PACKAGE();

    $self->yum->remove( CCS_PACKAGE(), @ccs_dependencies );

    return;
}

sub _load_ccs_modules ($self) {
    require Cpanel::LoadModule::Custom;

    Cpanel::LoadModule::Custom::load_perl_module('Cpanel::CCS::Delegates');
    Cpanel::LoadModule::Custom::load_perl_module('Cpanel::CCS::DBUtils');
    Cpanel::LoadModule::Custom::load_perl_module('Cpanel::CCS::Userdata');

    return;
}

=head1

This export code is largely based on the code in
'/var/cpanel/perl/Cpanel/Pkgacct/Components/CCSPkgAcct.pm' which is provided
by the CCS package.  Unfortunately, I could not call into that code here
as that code is intended to be used by '/scripts/pkgacct' and uses
'Cpanel::Pkgacct::Component' as a parent.  Due to that, I made the decision
to port that code over to elevate directly.

TL;DR: We will want to monitor CCS for bug fixes/changes as we may need to
update this code to resolve issues that get resolved there

=cut

sub export_ccs_data ($self) {
    my $export_dir = EXPORT_DIR();
    INFO("Exporting CCS data to '$export_dir'.  A backup of this data will be left in place after elevate completes.");
    $self->_ensure_export_directory();

    my @users = Cpanel::Config::Users::getcpusers();
    foreach my $user (@users) {
        INFO("    Exporting data for $user");
        $self->_export_data_for_single_user($user);
    }

    INFO('Completed exporting CCS data for all users');

    return;
}

sub _export_data_for_single_user ( $self, $user ) {
    my $users_ccs_info = $self->_get_ccs_info_for_user($user);
    my @webmail_users  = keys %{ $users_ccs_info->{users} };

    # Should be impossible to hit this condition, but be paranoid
    next if ( !@webmail_users );

    $self->_make_backup_paths_for_user($user);
    $self->_dump_persistence_data_for_user($user);
    $self->_dump_delegation_data_for_user($user);

    foreach my $webmail_user (@webmail_users) {
        $self->_process_calendar_and_contacts_for_webmail_user( $user, $webmail_user );
    }

    return;
}

sub _process_calendar_and_contacts_for_webmail_user ( $self, $user, $webmail_user ) {
    my $path           = $self->_get_export_path_for_user($user);
    my $users_ccs_info = $self->_get_ccs_info_for_user($user);
    my $uuid           = $users_ccs_info->{users}{$webmail_user};
    my %dump_types     = DUMP_TYPES();
    my $dbh            = $self->_get_dbh();

    foreach my $type ( keys %dump_types ) {
        my ( $query_string, $query_args ) = $self->_get_query_for_type( $type, $uuid );
        my $sth = $dbh->prepare($query_string);

        $sth->execute(@$query_args);

        my $num_rows = $sth->rows;
        next if !$num_rows;

        # Write the relevant file from the dump
        my $dump_file = "$path/$type/${uuid}_${type}.$dump_types{$type}";

        Cpanel::Autodie::open( my $dh, ">", $dump_file );
        binmode( $dh, ":encoding(UTF-8)" ) or die "Can't set binmode to UTF-8 on $dump_file: $!";

        while ( my $text = $sth->fetch ) {
            for (@$text) {
                my $txt = $_;
                $txt =~ tr/'//d;
                print $dh $txt;
            }
        }
    }

    return;
}

sub _dump_delegation_data_for_user ( $self, $user ) {
    my $path = $self->_get_export_path_for_user($user);
    my $dbh  = $self->_get_dbh();

    my @webmail_users_info = Cpanel::CCS::Userdata::get_users($user);
    my $delegates_ar       = Cpanel::CCS::Delegates::get( @webmail_users_info, $dbh );

    my $delegate_file = $path . '/' . 'delegates.json';
    Cpanel::JSON::DumpFile( $delegate_file, $delegates_ar );
    return;
}

sub _dump_persistence_data_for_user ( $self, $user ) {
    my $path             = $self->_get_export_path_for_user($user);
    my $persistence_file = $path . '/' . 'persistence.json';
    my $users_ccs_info   = $self->_get_ccs_info_for_user($user);

    Cpanel::JSON::DumpFile( $persistence_file, $users_ccs_info );
    return;
}

sub _make_backup_paths_for_user ( $self, $user ) {
    my $path = $self->_get_export_path_for_user($user);
    File::Path::make_path($path);

    my %dump_types = DUMP_TYPES();
    for ( keys(%dump_types) ) { File::Path::make_path("$path/$_"); }
    return;
}

sub _get_query_for_type ( $self, $type, $uuid ) {
    my %querydata = (
        'calendars' => {
            'args'  => [ $uuid, '1', 'f' ],
            'query' => "SELECT icalendar_text
                FROM
                  calendar_object
                  INNER JOIN calendar_bind ON calendar_bind.calendar_resource_id = calendar_object.calendar_resource_id
                  INNER JOIN calendar_metadata ON calendar_metadata.resource_id = calendar_bind.calendar_resource_id
                  INNER JOIN calendar_home ON calendar_home.resource_id = calendar_bind.calendar_home_resource_id
                WHERE calendar_home.owner_uid = ?
                AND calendar_bind.bind_status = ?
                AND calendar_metadata.is_in_trash = ?;",
        },
        'contacts' => {
            'args'  => [ $uuid, 'f' ],
            'query' => "SELECT vcard_text
                FROM
                  addressbook_object
                  INNER JOIN addressbook_home ON addressbook_home.resource_id = addressbook_object.addressbook_home_resource_id
                WHERE addressbook_home.owner_uid = ?
                AND addressbook_object.is_in_trash = ?;",
        },
    );

    return ( $querydata{$type}{'query'}, $querydata{$type}{'args'} );
}

sub _get_dbh ($self) {
    $self->{dbh} ||= Cpanel::CCS::DBUtils::get_dbh();
    return $self->{dbh};
}

sub _get_export_path_for_user ( $self, $user ) {
    $self->{$user}{export_path} ||= EXPORT_DIR() . '/' . $user . '/calendar_and_contacts';
    return $self->{$user}{export_path};
}

sub _get_ccs_info_for_user ( $self, $user ) {
    $self->{$user}{info} ||= Cpanel::CCS::Userdata::get_cpanel_account_users_uuids($user);
    return $self->{$user}{info};
}

sub _ensure_export_directory ($self) {
    File::Path::make_path(EXPORT_DIR);

    # Do not use File::Path to do this since it only
    # runs chmod if it creates the directory and we want
    # to make sure it is 0700 regardless if it was just created
    # or not
    chmod 0700, EXPORT_DIR;

    return;
}

####################################
##### post_distro_upgrade code below this ###
####################################

sub post_distro_upgrade ($self) {
    return unless Elevate::StageFile::read_stage_file('ccs_installed');

    $self->run_once('move_pgsql_directory');

    $self->_install_ccs_and_dependencies();

    # This needs to happen before verifying that the service is up
    # There is a task created that makes a schema update that can
    # cause CCS to fail to start
    $self->_clear_task_queue();

    $self->_ensure_ccs_service_is_up();
    $self->run_once('import_ccs_data');

    $self->move_pgsql_directory_back();

    return;
}

sub _install_ccs_and_dependencies ($self) {
    my @packages_to_install = ( CCS_PACKAGE() );

    push @packages_to_install, ZPUSH_PACKAGE() if Elevate::StageFile::read_stage_file('zpush_installed');

    $self->dnf->install(@packages_to_install);

    return;
}

sub _clear_task_queue ($self) {

    # CCS queues up tasks when it is first installed
    # These need to run before we attempt to import data
    $self->ssystem( TASK_QUEUE_SCRIPT, 'run' );
    return;
}

sub _ensure_ccs_service_is_up ($self) {

    INFO('Attempting to ensure that the CCS service is running');

    my $attempts     = 1;
    my $max_attempts = 5;
    while ( $attempts <= $max_attempts ) {
        DEBUG("Attempt $attempts of $max_attempts to verify that the CCS service is up");

        if ( $self->_ccs_service_is_up() ) {
            INFO('Verified that the CCS service is up');
            return;
        }

        # If the service was not up at this point, it is likely that
        # the schema update failed during the install.  In this case,
        # the only way I have found to get things working again is to
        # completely remove the package and start the install over

        $self->remove_ccs_and_dependencies();
        $self->remove_cpanel_ccs_home_directory();
        $self->_clear_task_queue();
        $self->_install_ccs_and_dependencies();
        $self->_clear_task_queue();

        sleep 5;
        $attempts++;
    }

    WARN("Failed to start CCS service.  Importing CCS data may fail.");
    return;
}

sub _attempt_to_start_service ($self) {
    $self->ssystem(CCS_RESTART_SCRIPT);
    return;
}

sub _ccs_service_is_up ($self) {
    my $out = $self->ssystem_capture_output( CCS_RESTART_SCRIPT, '--status' );
    return grep { $_ =~ m/is running as cpanel-ccs with PID/ } @{ $out->{stdout} };
}

sub import_ccs_data ($self) {
    INFO("Importing CCS data");

    my @failed_users;
    my @users = Cpanel::Config::Users::getcpusers();
    foreach my $user (@users) {
        try {
            INFO("    Importing data for $user");
            $self->_import_data_for_single_user($user);
        }
        catch {
            push @failed_users, $user;
        };
    }

    INFO('Completed importing CCS data for all users');

    if (@failed_users) {
        my $export_dir = EXPORT_DIR();
        my $message    = "The CCS data failed to import for the following users:\n\n";
        $message .= join "\n", sort(@failed_users);
        $message .= <<~"EOS";

        A backup of this data is located at $export_dir

        If this data is crucial, you may want to consider reaching out to cPanel Support for further assistance:

        https://docs.cpanel.net/knowledge-base/technical-support-services/how-to-open-a-technical-support-ticket/

        EOS

        Elevate::Notify::add_final_notification($message);
    }

    return;
}

sub _import_data_for_single_user ( $self, $user ) {

    require '/var/cpanel/perl5/lib/CCSHooks.pm';    ##no critic qw(RequireBarewordIncludes)

    my $extract_dir = EXPORT_DIR() . '/' . $user;
    my $import_data = {
        user        => $user,
        extract_dir => $extract_dir,
    };

    try {
        CCSHooks::pkgacct_restore( undef, $import_data );
    }
    catch {
        my $err = $_;
        WARN("Failed to restore CCS data for '$user'");
        DEBUG($err);
        die "CCS import failed for $user\n";
    };

    return;
}

=head1 move_pgsql_directory

Because CCS re-uses scripts originally intended for use with the system
Postgres, leaving the system Postgres data directory in place sometimes results
in failure to apply schema updates to CCS, causing failures in importing user
data. This is technically a bug in CCS, but we will not be issuing a fix for
that. Instead, when needed, the system Postgres database shall be moved aside,
ensuring that all and only CCS processes apply to that instance of Postgres.

=cut

sub move_pgsql_directory ($self) {
    my $pg_dir        = '/var/lib/pgsql';
    my $pg_backup_dir = '/var/lib/pgsql_pre_elevate';

    return unless -d $pg_dir;

    # Remove the backup path if it exists as a directory
    File::Path::remove_tree($pg_backup_dir) if -e $pg_backup_dir && -d $pg_backup_dir;

    INFO( <<~"EOS" );
    Temporarily moving the PostgreSQL data dir located at $pg_dir to $pg_backup_dir
    due to issues with the CCS upgrade process. This script will attempt to move the directory
    back to $pg_dir after CCS is upgraded.
    EOS

    # Using rename instead of File::Copy::move, because allowing copy+delete behavior introduces too many points of failure:
    my $success = rename( $pg_dir, $pg_backup_dir );
    LOGDIE(qq[The system failed to move $pg_dir to $pg_backup_dir (reason: $!)!]) unless $success;

    return;
}

sub move_pgsql_directory_back ($self) {
    my $pg_dir        = '/var/lib/pgsql';
    my $pg_backup_dir = '/var/lib/pgsql_pre_elevate';

    return unless -e $pg_backup_dir;

    INFO(qq[Restoring system PostgreSQL instance...]);

    Elevate::SystemctlService->new( name => 'postgresql' )->stop();    # just in case
    File::Path::remove_tree($pg_dir) if -e $pg_dir;

    my $result = rename( $pg_backup_dir, $pg_dir );
    if ( !$result ) {
        my $msg = <<~"EOS";
        The system could not fully restore $pg_backup_dir to $pg_dir (reason: $!).
        Restore this manually, and perform the update as recommended.
        EOS

        LOGDIE($msg);
        return;
    }

    INFO(qq[The system returned the PostgreSQL data directory to $pg_dir.]);
    return;
}

1;
