package Elevate::Components::RpmDB;

=encoding utf-8

=head1 NAME

Elevate::Components::RpmDB

=head2 check

noop

=head2 pre_distro_upgrade

1. Remove packages provided via rpm.versions
2. Remove obsolete packages that are not provided after upgrade

=head2 post_distro_upgrade

1. Install EPEL repo
2. Ensure epel and powertools repos are enabled
3. Force Perl reinstall
4. Update all packages
5. Execute sysup

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::OS        ();
use Elevate::PkgMgr    ();

use Cwd           ();
use Log::Log4perl qw(:easy);

use Cpanel::Pkgr      ();
use Cpanel::Yum::Vars ();

use parent qw{Elevate::Components::Base};

use constant OBSOLETE_PACKAGES => (
    'compat-db',
    'gd-progs',
    'python-tools',
    'python2-dnf',
    'python2-libcomps',
    'tcp_wrappers-devel',
    'tkinter',
    'yum-plugin-universal-hooks',
    'eigid',
    'quickinstall',
);

sub pre_distro_upgrade ($self) {

    $self->run_once("_cleanup_rpms");

    return;
}

sub _cleanup_rpms ($self) {

    # potential to remove other things, but the goal here to remove cpanel packages provided by rpm.versions
    Elevate::PkgMgr::remove_cpanel_arch_pkgs();

    # These packages are not available on 8 variants and will be removed by
    # leapp if we do not remove them manually.  Not necessarily a bug per se,
    # but it is better if we go ahead and handle removing these packages before
    # starting leapp
    $self->_remove_obsolete_packages();

    return;
}

sub _remove_obsolete_packages ($self) {

    # This is specific to leapp upgrades
    return unless Elevate::OS::needs_leapp();

    my @pkgs_to_remove = OBSOLETE_PACKAGES();
    Elevate::PkgMgr::remove(@pkgs_to_remove);
    return;
}

sub post_distro_upgrade ($self) {

    $self->run_once("_sysup");

    return;
}

sub _sysup ($self) {
    Cpanel::Yum::Vars::install();
    Elevate::PkgMgr::clean_all();

    if ( Elevate::OS::needs_epel() ) {
        my $epel_url = 'https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm';

        # no failures once already installed: no need to check for the
        # epel-release version
        unless ( Cpanel::Pkgr::is_installed('epel-release') ) {
            Elevate::PkgMgr::install_pkg_via_url($epel_url);
        }

        Elevate::PkgMgr::config_manager_enable('epel');
    }

    Elevate::PkgMgr::config_manager_enable('powertools') if Elevate::OS::needs_powertools();

    # Break cpanel-perl (NOTE: This only works on perl 5.36)
    unlink('/usr/local/cpanel/3rdparty/perl/536/cpanel-lib/X/Tiny.pm');
    {
        local $ENV{'CPANEL_BASE_INSTALL'} = 1;    # Don't fix more than perl itself.
        $self->ssystem(qw{/usr/local/cpanel/scripts/fix-cpanel-perl});
    }
    Elevate::PkgMgr::update_allow_erasing( '--disablerepo', 'cpanel-plugins' );
    $self->ssystem_and_die(qw{/usr/local/cpanel/scripts/sysup});

    return;
}

1;
