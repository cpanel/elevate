package Elevate::Components::NixStats;

=encoding utf-8

=head1 NAME

Elevate::Components::NixStats

Capture and reinstall NixStats packages.

=cut

use cPstrict;

use Elevate::Constants        ();
use Elevate::SystemctlService ();
use Elevate::Fetch            ();
use Elevate::Notify           ();
use Elevate::StageFile        ();

use Cwd           ();
use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

sub pre_distro_upgrade ($self) {

    $self->run_once("_remove_nixstats");

    return;
}

sub post_distro_upgrade ($self) {

    $self->run_once('_restore_nixstats');

    return;
}

sub has_nixstats {
    return -e q[/etc/systemd/system/nixstatsagent.service] || -e q[/usr/local/bin/nixstatsagent];
}

sub _remove_nixstats ($self) {

    return unless has_nixstats();

    INFO("Removing nixstats");

    my $backup_dir = Elevate::Constants::ELEVATE_BACKUP_DIR . "/nixstats";

    File::Path::make_path($backup_dir);
    die "Failed to create backup directory: $backup_dir" unless -d $backup_dir;

    my @to_backup = qw{ /etc/nixstats-token.ini /etc/nixstats.ini };

    # files we need to restore later
    my $to_restore = {};

    foreach my $f (@to_backup) {
        next unless -f $f;
        my $name   = File::Basename::basename($f);
        my $backup = "$backup_dir/$name";
        File::Copy::move( $f, $backup );

        $to_restore->{$backup} = $f;
    }

    my $service_name = q[nixstatsagent];
    my $service      = Elevate::SystemctlService->new( name => $service_name );

    my $is_enabled = $service->is_enabled;

    $service->disable if $is_enabled;
    $service->stop;

    my $pip;

    if ( -x q[/usr/bin/pip3] ) {
        $pip = q[/usr/bin/pip3];
    }
    elsif ( -x q[/usr/bin/pip] ) {
        $pip = q[/usr/bin/pip];
    }

    if ($pip) {
        $self->ssystem( $pip, qw{uninstall -y nixstatsagent} );
    }
    else {
        ERROR("Cannot remove nixstatsagent: cannot find pip binary");
    }

    my $data = {
        service_enabled => $is_enabled,
        to_restore      => $to_restore,
    };

    Elevate::StageFile::update_stage_file( { 'reinstall' => { 'nixstats' => $data } } );

    return;
}

sub _restore_nixstats ($self) {
    my $data = Elevate::StageFile::read_stage_file('reinstall')->{'nixstats'};
    return unless ref $data;

    INFO("Restoring nixstats");

    # we reinstall nixstats using a non existing user id
    #   this avoid adding some polution to their account
    #   by creating a server we are then going to replace just after
    # alternatively we could use the user from the nixstats-token.ini file
    my $user = q[deadbeefdeadbeefdeadbeef];

    my $installer_script = Elevate::Fetch::script( 'https://www.nixstats.com/nixstatsagent.sh', 'nixstatsagent' );

    $self->ssystem( '/usr/bin/bash', $installer_script, $user );

    unlink $installer_script;

    if ( !-x q[/usr/local/bin/nixstatsagent] ) {
        ERROR("Missing nixstatsagent binary: /usr/local/bin/nixstatsagent");
    }

    my $service = q[nixstatsagent];

    # Stopping the agent
    $self->ssystem( qw{/usr/bin/systemctl stop}, $service );

    # Restoring backup files
    my $to_restore = $data->{to_restore};

    foreach my $src ( sort keys %$to_restore ) {
        my $destination = $to_restore->{$src};

        File::Copy::copy( $src, $destination );
    }

    # restoring the state of the service before elevation
    if ( $data->{service_enabled} ) {
        $self->ssystem( qw{/usr/bin/systemctl enable}, $service );
    }
    else {    # leave it disabled
        $self->ssystem( qw{/usr/bin/systemctl disable}, $service );
    }

    # do not really need to start/stop the daemon, we are about to reboot
    #   but start it for sanity purpose

    $self->ssystem( qw{/usr/bin/systemctl start}, $service );
    if ( $? == 0 ) {
        INFO("nixstatsagent restored");
    }
    else {
        Elevate::Notify::add_final_notification( "Failed to start nixstatsagent.service", 1 );
    }

    return;
}

1;
