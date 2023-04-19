package Elevate::Components::Imunify360;

=encoding utf-8

=head1 NAME

Elevate::Components::Imunify360

Capture and reinstall Imunify360 packages.

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::Fetch     ();

use Cpanel::JSON ();
use Cpanel::Pkgr ();
use Cwd          ();

use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

sub pre_leapp ($self) {

    $self->run_once('_remove_imunify_360');

    return;
}

sub post_leapp ($self) {

    $self->run_once('_reinstall_imunify_360');

    return;
}

sub is_installed ($self) {

    # One of these 2 rpms should be in place or imunify isn't really functioning.

    return Cpanel::Pkgr::is_installed('imunify360-firewall')
      || Cpanel::Pkgr::is_installed('imunify-antivirus');
}

sub _remove_imunify_360 ($self) {

    return unless $self->is_installed;

    my $agent_bin = Elevate::Constants::IMUNIFY_AGENT;
    return unless -x $agent_bin;

    my $license_data = eval { Cpanel::JSON::Load(`$agent_bin version --json 2>&1`) } // {};
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
        FATAL("Imunify360: Fail to fetch script for $product_type. Skipping upgrade.");
        die;
    };
    if ( $self->ssystem( '/usr/bin/bash', $installer_script, '--uninstall' ) != 0 ) {
        FATAL("Imunify360: Fail to uninstall $product_type.");
        die;
    }
    unlink $installer_script;

    cpev::update_stage_file( { 'reinstall' => { 'imunify360' => $product_type } } );

    # Cleanup any lingering packages.
    $self->remove_rpms_from_repos('imunify');

    return;
}

sub _reinstall_imunify_360 ($self) {
    my $product_type = cpev::read_stage_file('reinstall')->{'imunify360'} or return;

    INFO("Reinstalling $product_type");

    my $installer_script = _fetch_imunify_installer($product_type) or return;

    if ( $self->ssystem( '/usr/bin/bash', $installer_script ) != 0 ) {
        ERROR("Fail to reinstall $product_type.");
    }
    unlink $installer_script;

    return;
}

sub _fetch_imunify_installer ($product) {

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

    return Elevate::Fetch::script( $installer_url, 'imunify_installer' );
}

1;
