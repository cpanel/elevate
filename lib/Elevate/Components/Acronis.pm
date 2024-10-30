package Elevate::Components::Acronis;

=encoding utf-8

=head1 NAME

Elevate::Components::Acronis

=head2 check

noop

=head2 pre_distro_upgrade

Find out if Acronis is installed.
If it is, uninstall it & make a note in the stage file.
(We'll need to reinstall it after the OS upgrade.)

=head2 post_distro_upgrade

If the agent had been installed:
Re-install the agent.

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::PkgMgr    ();
use Elevate::StageFile ();

use Cpanel::Pkgr ();

use parent qw{Elevate::Components::Base};

sub pre_distro_upgrade ($self) {

    return unless Cpanel::Pkgr::is_installed(Elevate::Constants::ACRONIS_BACKUP_PACKAGE);

    Elevate::PkgMgr::remove(
        Elevate::Constants::ACRONIS_BACKUP_PACKAGE,
        Elevate::Constants::ACRONIS_OTHER_PACKAGES
    );

    Elevate::StageFile::update_stage_file( { 'reinstall' => { 'acronis' => 1 } } );

    return;
}

sub post_distro_upgrade ($self) {

    return unless Elevate::StageFile::read_stage_file('reinstall')->{'acronis'};

    Elevate::PkgMgr::install(Elevate::Constants::ACRONIS_BACKUP_PACKAGE);

    return;
}

1;
