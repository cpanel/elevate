package Elevate::PkgMgr::Base;

=encoding utf-8

=head1 NAME

Elevate::PkgMgr::Base

This is a base class used by Elevate::PkgMgr::*

=cut

use cPstrict;

use File::Copy ();

use Cpanel::Pkgr ();

use parent 'Elevate::Roles::Run';

sub new ( $class, $opts = undef ) {
    $opts //= {};

    my $self = {%$opts};
    bless $self, $class;

    return $self;
}

sub name ($self) {
    die "name unimplemented";
}

sub _pkgmgr ($self) {
    die "_pkgmgr unimplemented";
}

sub get_config_files_for_pkg_prefix ( $self, $prefix ) {

    my @installed_pkgs = $self->get_installed_pkgs(q[%{NAME}\n]);
    my @wanted_pkgs    = grep { $_ =~ qr/^\Q$prefix\E/ } @installed_pkgs;
    my $config_files   = $self->get_config_files( \@wanted_pkgs );

    return $config_files;
}

sub _get_config_file_suffix ($self) {
    die "_get_config_file_suffix unimplemented";
}

sub get_config_files ( $self, $pkgs ) {
    die "get_config_files unimplemented";
}

sub restore_config_files ( $self, @files ) {
    my $suffix = $self->_get_config_file_suffix();

    foreach my $file (@files) {
        next unless length $file;

        my $backup_file = $file . $suffix;

        next unless -e $backup_file;

        File::Copy::mv( $backup_file, $file ) or WARN("Unable to restore config file $backup_file: $!");
    }

    return;
}

sub remove_no_dependencies ( $self, $pkg ) {
    return Cpanel::Pkgr::remove_packages_nodeps($pkg);
}

sub remove_no_dependencies_and_justdb ( $self, $pkg ) {
    die "remove_no_dependencies_and_justdb unimplemented";
}

sub remove_no_dependencies_or_scripts_and_justdb ( $self, $pkg ) {
    die "remove_no_dependencies_or_scripts_and_justdb unimplemented";
}

sub force_upgrade_pkg ( $self, $pkg ) {
    die "force_upgrade_pkg unimplemented";
}

sub get_installed_pkgs ( $self, $format = undef ) {
    die "get_installed_pkgs unimplemented";
}

sub get_cpanel_arch_pkgs ($self) {
    my @installed_pkgs   = $self->get_installed_pkgs();
    my @cpanel_arch_pkgs = grep { $_ =~ m/^cpanel-.*\.x86_64$/ } @installed_pkgs;
    return @cpanel_arch_pkgs;
}

sub remove_cpanel_arch_pkgs ($self) {
    my @pkgs_to_remove = $self->get_cpanel_arch_pkgs();

    foreach my $pkg (@pkgs_to_remove) {
        $self->remove_no_dependencies_and_justdb($pkg);
    }

    return;
}

sub remove ( $self, @pkgs ) {
    die "remove unimplemented";
}

sub clean_all ($self) {
    die "clean_all unimplemented";
}

sub install_pkg_via_url ( $self, $rpm_url ) {
    die "install_pkg_via_url unimplemented";
}

sub install_with_options ( $self, $options, $pkgs ) {
    die "install_with_options unimplemented";
}

sub install ( $self, @pkgs ) {
    die "install unimplemented";
}

sub reinstall ( $self, @pkgs ) {
    die "reinstall unimplemented";
}

sub repolist_all ($self) {
    die "repolist_all unimplemented";
}

sub repolist_enabled ($self) {
    die "repolist_enabled unimplemented";
}

sub repolist ( $self, @options ) {
    die "repolist unimplemented";
}

sub get_extra_packages ($self) {
    die "get_extra_packages unimplemented";
}

sub config_manager_enable ( $self, $repo ) {
    die "config_manager_enable unimplemented";
}

sub update ($self) {
    die "update unimplemented";
}

sub update_with_options ( $self, $options, $pkgs ) {
    die "update_with_options unimplemented";
}

sub update_allow_erasing ( $self, @additional_args ) {
    die "update_allow_erasing unimplemented";
}

sub makecache ($self) {
    die "makecache unimplemented";
}

sub pkg_list ( $self, $invalidate_cache = 0 ) {
    die "pkg_list unimplemented";
}

sub get_installed_pkgs_in_repo ( $self, @pkg_list ) {
    die "get_installed_pkgs_in_repo unimplemented";
}

sub remove_pkgs_from_repos ( $self, @pkg_list ) {
    die "remove_pkgs_from_repos unimplemented";
}

1;
