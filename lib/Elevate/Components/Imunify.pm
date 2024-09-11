package Elevate::Components::Imunify;

=encoding utf-8

=head1 NAME

Elevate::Components::Imunify

Capture and reinstall Imunify packages.

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::Fetch     ();
use Elevate::Notify    ();
use Elevate::OS        ();
use Elevate::StageFile ();

use Cwd           ();
use Log::Log4perl qw(:easy);

use Cpanel::JSON            ();
use Cpanel::Pkgr            ();
use Cpanel::SafeRun::Simple ();
use File::Copy              ();
use Cwd                     ();

use parent qw{Elevate::Components::Base};

use constant IMUNIFY_AGENT          => Elevate::Constants::IMUNIFY_AGENT;                                         # ya alias
use constant IMUNIFY_LICENSE_FILE   => '/var/imunify360/license.json';
use constant IMUNIFY_LICENSE_BACKUP => Elevate::Constants::ELEVATE_BACKUP_DIR . '/imunify-backup-license.json';

sub pre_distro_upgrade ($self) {

    return if Elevate::OS::leapp_can_handle_imunify();

    return unless $self->is_installed;

    $self->run_once("_capture_imunify_features");
    $self->run_once("_capture_imunify_packages");
    $self->run_once('_remove_imunify_360');

    return;
}

sub post_distro_upgrade ($self) {

    return if Elevate::OS::leapp_can_handle_imunify();

    # order matters
    $self->run_once('_reinstall_imunify_360');
    $self->run_once('_restore_imunify_features');
    $self->run_once("_restore_imunify_packages");

    return;
}

sub _capture_imunify_packages ($self) {

    # only capture the imunify packages
    my @packages = grep { m/^imunify-/ } cpev::get_installed_rpms_in_repo(qw{ imunify imunify360 });

    return unless scalar @packages;

    Elevate::StageFile::update_stage_file( { 'reinstall' => { 'imunify_packages' => \@packages } } );

    return;
}

sub _restore_imunify_packages ($self) {

    # try to reinstall missing Imunify packages which were previously installed

    return unless my $packages = Elevate::StageFile::read_stage_file('reinstall')->{'imunify_packages'};

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
    my @features = map {
        my $trim_spaces = $_;
        $trim_spaces =~ s/\s+//g;
        $trim_spaces;
    } grep { m/\S/ } split( "\n", $output );

    if ( -f IMUNIFY_LICENSE_FILE ) {
        File::Copy::move( IMUNIFY_LICENSE_FILE, IMUNIFY_LICENSE_BACKUP );
    }

    Elevate::StageFile::update_stage_file( { 'reinstall' => { 'imunify_features' => \@features } } );

    return;
}

sub _restore_imunify_features {

    return unless my $features = Elevate::StageFile::read_stage_file('reinstall')->{'imunify_features'};

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
            $partial_line .= $read;
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

sub is_installed ($self) {

    return unless -x Elevate::Constants::IMUNIFY_AGENT;
    return 1;
}

sub has_360_installed ($self) {

    # One of these 2 rpms should be in place or imunify isn't really functioning.
    return Cpanel::Pkgr::is_installed('imunify360-firewall')
      || Cpanel::Pkgr::is_installed('imunify-antivirus');
}

sub _remove_imunify_360 ($self) {

    return unless $self->has_360_installed;

    my $agent_bin    = Elevate::Constants::IMUNIFY_AGENT;
    my $out          = $self->ssystem_capture_output( $agent_bin, 'version', '--json' );
    my $raw_data     = join "\n", @{ $out->{stdout} };
    my $license_data = eval { Cpanel::JSON::Load($raw_data) } // {};
    if (   !ref $license_data->{'license'}
        || !$license_data->{'license'}->{'status'} ) {
        WARN("Imunify360: Cannot detect license. Skipping upgrade.");
        return;
    }

    my $product_type = $license_data->{'license'}->{'license_type'} or do {
        WARN("Imunify360: No license type detected. Skipping upgrade.");
        return;
    };

    INFO("Imunify360: Removing $product_type prior to upgrade.");
    INFO("Imunify360: Product $product_type detected. Uninstalling before upgrade for later restore.");

    my $installer_script = _fetch_imunify_installer($product_type) or do {
        WARN("Imunify360: Failed to fetch script for $product_type. Skipping upgrade.");
        return;
    };
    if ( $self->ssystem( '/usr/bin/bash', $installer_script, '--uninstall' ) != 0 ) {
        WARN("Imunify360: Failed to uninstall $product_type.");
        return;
    }
    unlink $installer_script;

    Elevate::StageFile::update_stage_file( { 'reinstall' => { 'imunify360' => $product_type } } );

    # Cleanup any lingering packages.
    $self->remove_rpms_from_repos('imunify');

    return;
}

sub _reinstall_imunify_360 ($self) {
    my $product_type = Elevate::StageFile::read_stage_file('reinstall')->{'imunify360'} or return;

    INFO("Reinstalling $product_type");

    my $installer_script = _fetch_imunify_installer($product_type) or return;

    if ( $self->ssystem( '/usr/bin/bash', $installer_script ) == 0 ) {
        INFO("Successfully reinstalled $product_type.");
    }
    else {
        my $installer_url = _script_url_for_product($product_type);
        my $msg           = "Failed to reinstall $product_type. Please reinstall it manually using $installer_url.";
        ERROR($msg);
        Elevate::Notify::add_final_notification($msg);
    }

    unlink $installer_script;

    return;
}

sub _script_url_for_product ($product) {
    $product =~ s/Plus/+/i;

    my %installer_scripts = (
        'imunifyAV'  => 'https://repo.imunify360.cloudlinux.com/defence360/imav-deploy.sh',
        'imunifyAV+' => 'https://repo.imunify360.cloudlinux.com/defence360/imav-deploy.sh',
        'imunify360' => 'https://www.repo.imunify360.cloudlinux.com/defence360/i360deploy.sh',
    );

    my $installer_url = $installer_scripts{$product} or do {
        ERROR( "_fetch_imunify_installer: Unknown product type '$product'. Known products are: " . join( ', ', sort keys %installer_scripts ) );
        return;
    };

    return $installer_url;
}

sub _fetch_imunify_installer ($product) {

    my $installer_url = _script_url_for_product($product) or return;
    return Elevate::Fetch::script( $installer_url, 'imunify_installer' );
}

1;
