package Elevate::Components::WPToolkit;

=encoding utf-8

=head1 NAME

Elevate::Components::WPToolkit

=head2 check

noop

=head2 pre_distro_upgrade

Remove wp-toolkit

=head2 post_distro_upgrade

Reinstall wp-toolkit

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::Fetch     ();
use Elevate::PkgMgr    ();
use Elevate::StageFile ();

use Cwd                     ();
use File::Copy              ();
use Log::Log4perl           qw(:easy);

use parent qw{Elevate::Components::Base};

sub pre_distro_upgrade ($self) {

    $self->run_once("_remove_wordpress_toolkit");

    return;
}

sub post_distro_upgrade ($self) {

    $self->run_once('_reinstall_wordpress_toolkit');

    return;
}

sub _remove_wordpress_toolkit ($self) {
    return unless Cpanel::Pkgr::is_installed('wp-toolkit-cpanel');

    INFO("Removing Wordpress Toolkit");

    INFO("Removing the rpm wp-toolkit-cpanel");
    backup_3rdparty_file('/usr/local/cpanel/3rdparty/wp-toolkit/var/wp-toolkit.sqlite3');
    backup_3rdparty_file('/usr/local/cpanel/3rdparty/wp-toolkit/var/etc/.shadow');

    Elevate::PkgMgr::remove('wp-toolkit-cpanel');

    $self->remove_rpms_from_repos(qw/wp-toolkit-cpanel wp-toolkit-thirdparties/);

    Elevate::StageFile::update_stage_file( { 'reinstall' => { 'wordpress_toolkit' => 1 } } );

    return;
}

sub _reinstall_wordpress_toolkit ($self) {
    return unless Elevate::StageFile::read_stage_file('reinstall')->{'wordpress_toolkit'};

    INFO("Restoring Wordpress Toolkit");
    my $installer_script = Elevate::Fetch::script( 'https://wp-toolkit.plesk.com/cPanel/installer.sh', 'wptk_installer' );

    $self->ssystem( '/usr/bin/bash', $installer_script );
    unlink $installer_script;

    return;
}

sub backup_3rdparty_file ($file) {
    my $target = "$file.elevate_backup";
    return File::Copy::cp( $file, $target );
}

1;
