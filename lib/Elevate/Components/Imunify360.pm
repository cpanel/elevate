package Elevate::Components::Imunify360;

=encoding utf-8

=head1 NAME

Elevate::Components::Imunify360

Capture and reinstall Imunify360 packages.

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::Fetch     ();

use Cpanel::JSON  ();
use Cwd           ();
use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

sub pre_leapp ($self) {

    $self->run_once("_remove_imunify_360");

    return;
}

sub post_leapp ($self) {

    $self->run_once('_reinstall_imunify_360');

    return;
}

sub _remove_imunify_360 ($self) {

    # One of these 2 rpms should be in place or imunify isn't really functioning.
    my $im360 = Cpanel::Pkgr::is_installed('imunify360-firewall');
    my $imav  = Cpanel::Pkgr::is_installed('imunify-antivirus');
    return unless $im360 || $imav;

    my $agent_bin = Elevate::Constants::IMUNIFY_AGENT;
    return unless -x $agent_bin;
    my $license_data = eval { Cpanel::JSON::Load(`$agent_bin version --json 2>&1`) } // {};
    return unless $license_data->{'license'}->{'status'};    # Must be true.

    my $product_type = $license_data->{'license'}->{'license_type'};

    INFO("Removing $product_type prior to upgrade.");

    cpev::update_stage_file( { 'reinstall' => { 'imunify' => $product_type } } );
    INFO("Product $product_type detected. Uninstalling before upgrade for later restore");

    my $installer_script = _fetch_imunify_installer($product_type) or return;

    $self->ssystem( '/usr/bin/bash', $installer_script, '--uninstall' );
    unlink $installer_script;

    # Cleanup any lingering packages.
    $self->remove_rpms_from_repos('imunify');

    return;
}

sub _reinstall_imunify_360 ($self) {
    my $product_type = cpev::read_stage_file('reinstall')->{'imunify'} or return;

    my $installer_script = _fetch_imunify_installer($product_type) or return;

    $self->ssystem( '/usr/bin/bash', $installer_script );
    unlink $installer_script;

    return;
}

sub _fetch_imunify_installer ($product) {

    $product =~ s/Plus/+/;
    my %installer_scripts = (
        'imunifyAV'  => 'https://repo.imunify360.cloudlinux.com/defence360/imav-deploy.sh',
        'imunifyAV+' => 'https://repo.imunify360.cloudlinux.com/defence360/imav-deploy.sh',
        'imunify360' => 'https://www.repo.imunify360.cloudlinux.com/defence360/i360deploy.sh',
    );

    my $installer_url = $installer_scripts{$product} or do {
        ERROR("Unknown product type $product");
        return;
    };

    return Elevate::Fetch::script( $installer_url, 'imunify_installer' );
}

1;
