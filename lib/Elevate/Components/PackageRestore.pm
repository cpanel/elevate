package Elevate::Components::PackageRestore;

=encoding utf-8

=head1 NAME

Elevate::Components::PackageRestore

=head2 check

noop

=head2 pre_distro_upgrade

Detect which packages in our list are installed and store our findings

=head2 post_distro_upgrade

Reinstall any packages detected pre distro upgrade

=cut

use cPstrict;

use Elevate::PkgUtility ();
use Elevate::StageFile  ();

use Cpanel::Pkgr ();

use parent qw{Elevate::Components::Base};

#
# Set as a function for unit testing
#
sub _get_packages_to_check () {
    return qw{
      net-snmp
    };
}

sub pre_distro_upgrade ($self) {

    my @package_list = _get_packages_to_check();
    my @installed_packages;

    foreach my $package (@package_list) {
        if ( Cpanel::Pkgr::is_installed($package) ) {
            push @installed_packages, $package;
        }
    }

    my $config_files = Elevate::PkgUtility::get_config_files( \@installed_packages );

    Elevate::StageFile::update_stage_file(
        {
            'packages_to_restore' => $config_files,
        }
    );

    return;
}

sub post_distro_upgrade ($self) {

    my $package_info = Elevate::StageFile::read_stage_file('packages_to_restore');
    return unless defined $package_info and ref $package_info eq 'HASH';

    foreach my $package ( keys %$package_info ) {

        $self->dnf->install($package);

        Elevate::PkgUtility::restore_config_files( @{ $package_info->{$package} } );
    }

    return;
}

1;
