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

use Elevate::PkgMgr    ();
use Elevate::StageFile ();

use Cpanel::Pkgr ();

use parent qw{Elevate::Components::Base};

#
# Set as a function for unit testing
#
# Returns a hash of package names and whether or not they should be removed
# from the system during the pre_distro_upgrade phase
# For some packages the uninstall/reinstall is handled elsewhere and
# we would like to only backup and restore the config files
#
sub _get_packages_to_check () {
    return (
        'net-snmp'    => 1,
        'sys-snap'    => 1,
        'cpanel-exim' => 0,
    );
}

sub pre_distro_upgrade ($self) {

    my %package_list = _get_packages_to_check();
    my @installed_packages;

    foreach my $package ( keys %package_list ) {
        if ( Cpanel::Pkgr::is_installed($package) ) {
            push @installed_packages, $package;
        }
    }

    # only remove the packages that are installed and flagged for removal
    my @packages_to_remove = grep { $package_list{$_} } @installed_packages;

    Elevate::PkgMgr::remove(@packages_to_remove);

    my $config_files = Elevate::PkgMgr::get_config_files( \@installed_packages );

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

        Elevate::PkgMgr::install($package) unless Cpanel::Pkgr::is_installed($package);

        Elevate::PkgMgr::restore_config_files( @{ $package_info->{$package} } );
    }

    return;
}

1;
