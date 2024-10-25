package Elevate::PkgUtility;

=encoding utf-8

=head1 NAME

Elevate::PkgUtility

Generic parent class for the logic wrapping the systems package utilities such
as rpm and dpkg

=cut

use cPstrict;

use Elevate::PkgUtility::RPM ();

our $PKGUTILITY;

sub factory {

    my $pkg = 'Elevate::PkgUtility::' . Elevate::OS::package_utility();
    return $pkg->new;
}

sub instance {
    $PKGUTILITY //= factory();
    return $PKGUTILITY;
}

sub name () {
    return instance()->name();
}

sub get_config_files_for_pkg_prefix ($prefix) {
    return instance()->get_config_files_for_pkg_prefix($prefix);
}

sub get_config_files ($pkgs) {
    return instance()->get_config_files($pkgs);
}

sub restore_config_files (@files) {
    return instance()->restore_config_files(@files);
}

sub remove_no_dependencies ($pkg) {
    return instance()->remove_no_dependencies($pkg);
}

sub remove_no_dependencies_and_justdb ($pkg) {
    return instance()->remove_no_dependencies_and_justdb($pkg);
}

sub remove_no_dependencies_or_scripts_and_justdb ($pkg) {
    return instance()->remove_no_dependencies_or_scripts_and_justdb($pkg);
}

sub force_upgrade_rpm ($pkg) {
    return instance()->force_upgrade_rpm($pkg);
}

sub get_installed_rpms ( $format = undef ) {
    return instance()->get_installed_rpms($format);
}

sub get_cpanel_arch_rpms () {
    return instance()->get_cpanel_arch_rpms();
}

sub remove_cpanel_arch_rpms () {
    return instance()->remove_cpanel_arch_rpms();
}

1;
