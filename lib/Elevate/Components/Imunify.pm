package Elevate::Components::Imunify;

=encoding utf-8

=head1 NAME

Elevate::Components::Imunify

Capture and reinstall Imunify packages.

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::Notify    ();

use Cwd           ();
use Log::Log4perl qw(:easy);

use Cpanel::JSON            ();
use Cpanel::Pkgr            ();
use Cpanel::SafeRun::Simple ();
use File::Copy              ();

use parent qw{Elevate::Components::Base};

use constant IMUNIFY_AGENT          => Elevate::Constants::IMUNIFY_AGENT;                                         # ya alias
use constant IMUNIFY_LICENSE_FILE   => '/var/imunify360/license.json';
use constant IMUNIFY_LICENSE_BACKUP => Elevate::Constants::ELEVATE_BACKUP_DIR . '/imunify-backup-license.json';

sub pre_leapp ($self) {

    $self->run_once("_capture_imunify_features");
    $self->run_once("_capture_imunify_packages");

    return;
}

sub post_leapp ($self) {

    $self->run_once('_restore_imunify_features');

    # this is happening after Imunify360 component
    $self->run_once("_restore_imunify_packages");

    return;
}

sub _capture_imunify_packages ($self) {

    # only capture the imunify packages
    my @packages = grep { m/^imunify-/ } cpev::get_installed_rpms_in_repo(qw{ imunify imunify360 });

    return unless scalar @packages;

    cpev::update_stage_file( { 'reinstall' => { 'imunify_packages' => \@packages } } );

    return;
}

sub _restore_imunify_packages ($self) {

    # try to reinstall missing Imunify packages which were previously installed

    return unless my $packages = cpev::read_stage_file('reinstall')->{'imunify_packages'};

    foreach my $pkg (@$packages) {
        next unless Cpanel::Pkgr::is_installed($pkg);
        INFO("Try to reinstall Imunify package: $pkg");
        $self->ssystem( qw{ /usr/bin/dnf -y install }, $pkg );
    }

    return;
}

sub _capture_imunify_features {
    return unless -x IMUNIFY_AGENT;

    my $output   = Cpanel::SafeRun::Simple::saferunnoerror( IMUNIFY_AGENT, qw{features list} );
    my @features = map { s/\s+//g; $_ } grep { m/\S/ } split( "\n", $output );

    if ( -f IMUNIFY_LICENSE_FILE ) {
        File::Copy::move( IMUNIFY_LICENSE_FILE, IMUNIFY_LICENSE_BACKUP );
    }

    cpev::update_stage_file( { 'reinstall' => { 'imunify_features' => \@features } } );

    return;
}

sub _restore_imunify_features {

    return unless my $features = cpev::read_stage_file('reinstall')->{'imunify_features'};

    File::Copy::move( IMUNIFY_LICENSE_BACKUP, IMUNIFY_LICENSE_FILE ) if -f IMUNIFY_LICENSE_BACKUP;

    return unless ref $features eq 'ARRAY';
    return unless @$features;

    INFO("Restoring imunify 360 features.");
    foreach my $feature (@$features) {
        INFO("Restoring imunify360 $feature");
        my $log_file = Cpanel::SafeRun::Simple::saferunnoerror( IMUNIFY_AGENT, qw{features install }, $feature );
        $log_file or next;
        chomp $log_file;
        next unless $log_file =~ m/\S/;

        __monitor_imunify_feature_install( $feature, $log_file );
    }

    return;
}

sub __imunify_feature_install_status ($feature) {
    my $install_status = eval {
        my $json = Cpanel::SafeRun::Simple::saferunnoerror( IMUNIFY_AGENT, qw{features status}, $feature, '--json' ) // '{}';
        Cpanel::JSON::Load($json);
    } // {};

    my $status = $install_status->{'items'}->{'status'} // '';

    return $status if $status =~ m/^(installed|installing|not_installed)$/i;
    return $install_status->{'items'}->{'message'} || "$feature is unknown";
}

# Wait 20 mins for the pid to finish.
sub __monitor_imunify_feature_install ( $feature, $log_file ) {

    my $start = time;
    while ( time - $start < 30 ) {
        my $status = __imunify_feature_install_status($feature);
        last if ( $status eq 'installed' || $status eq 'installing' && -e $log_file );
    }

    open( my $fh, '<', $log_file ) or do {
        my $status = __imunify_feature_install_status($feature);
        WARN("Could not open $log_file for monitoring ($!). The install of $feature is in state: $status");
        return;
    };

    DEBUG("Monitoring $log_file for completion");

    # Tail the log file and monitor status of the install by making agent queries.
    $start = time;
    my $partial_line = '';
    while ( time - $start < 60 * 20 ) {    # abort after 20 minutes.

        # Tail the file for new information.
        while ( my $read = <$fh> ) {
            my $partial_line .= $read;
            if ( length $read && substr( $partial_line, -1, 1 ) eq "\n" ) {
                INFO($partial_line);
                $partial_line = '';
            }
        }

        # This takes 1.5 seconds to query every time.
        my $status = __imunify_feature_install_status($feature);
        if ( $status eq 'installed' ) {
            INFO("Restore of $feature complete.");
            return 1;
        }
        if ( $status ne 'installing' ) {
            FATAL("Failed to install imunify 360 feature $feature ($status)");
            FATAL("See $log_file for more information");
            return 0;
        }

        sleep 5;
    }

    Elevate::Notify::add_final_notification( "Imunify failed to install feature $feature", 1 );

    return 0;
}
1;
