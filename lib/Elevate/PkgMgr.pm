package Elevate::PkgMgr;

=encoding utf-8

=head1 NAME

Elevate::PkgMgr

Generic parent class for the logic wrapping the systems package utilities such
as rpm and dpkg

=cut

use cPstrict;

use Elevate::PkgMgr::YUM ();

our $PKGUTILITY;

sub factory {

    my $pkg = 'Elevate::PkgMgr::' . Elevate::OS::package_manager();
    return $pkg->new;
}

sub instance {
    $PKGUTILITY //= factory();
    return $PKGUTILITY;
}

# Used in tests to verify that the factory is returning the correct thing
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

sub force_upgrade_pkg ($pkg) {
    return instance()->force_upgrade_pkg($pkg);
}

sub get_installed_pkgs ( $format = undef ) {
    return instance()->get_installed_pkgs($format);
}

sub get_cpanel_arch_pkgs () {
    return instance()->get_cpanel_arch_pkgs();
}

sub remove_cpanel_arch_pkgs () {
    return instance()->remove_cpanel_arch_pkgs();
}

sub remove (@pkgs) {
    return instance()->remove(@pkgs);
}

sub clean_all () {
    return instance()->clean_all();
}

sub install_pkg_via_url ($rpm_url) {
    return instance()->install_pkg_via_url($rpm_url);
}

sub install_with_options ( $options, $pkgs ) {
    return instance()->install_with_options( $options, $pkgs );
}

sub install (@pkgs) {
    return instance()->install(@pkgs);
}

sub reinstall (@pkgs) {
    return instance()->reinstall(@pkgs);
}

sub repolist_all () {
    return instance()->repolist_all();
}

sub repolist_enabled () {
    return instance()->repolist_enabled();
}

sub repolist (@options) {
    return instance()->repolist(@options);
}

sub get_extra_packages () {
    return instance()->get_extra_packages();
}

sub config_manager_enable ($repo) {
    return instance()->config_manager_enable($repo);
}

sub update () {
    return instance()->update();
}

sub update_with_options ( $options, $pkgs ) {
    return instance()->update_with_options( $options, $pkgs );
}

sub update_allow_erasing (@additional_args) {
    return instance()->update_allow_erasing(@additional_args);
}

sub makecache () {
    return instance()->makecache();
}

sub pkg_list ( $invalidate_cache = 0 ) {
    return instance()->pkg_list($invalidate_cache);
}

sub get_installed_pkgs_in_repo (@pkg_list) {
    return instance()->get_installed_pkgs_in_repo(@pkg_list);
}

sub remove_pkgs_from_repos (@pkg_list) {
    return instance()->remove_pkgs_from_repos(@pkg_list);
}

1;
