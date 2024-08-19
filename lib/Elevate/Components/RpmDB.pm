package Elevate::Components::RpmDB;

=encoding utf-8

=head1 NAME

Elevate::Components::RpmDB

Perform some maintenance on the RPM database.

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::DNF       ();
use Elevate::OS        ();

use Cwd           ();
use File::Copy    ();
use File::Slurper ();

use Log::Log4perl qw(:easy);

use Cpanel::Pkgr      ();
use Cpanel::Yum::Vars ();

use parent qw{Elevate::Components::Base};

use constant APT_LIST_D => q[/etc/apt/sources.list.d];

use constant OBSOLETE_PACKAGES => (
    'compat-db',
    'gd-progs',
    'python-tools',
    'python2-dnf',
    'python2-libcomps',
    'tcp_wrappers-devel',
    'tkinter',
    'yum-plugin-universal-hooks',
);

sub pre_leapp ($self) {

    $self->run_once("_cleanup_rpms");

    return;
}

sub _cleanup_rpms ($self) {

    # potential to remove other things, but the goal here to remove cpanel packages provided by rpm.versions
    $self->get_package_utility->remove_cpanel_arch_rpms();

    # These packages are not available on 8 variants and will be removed by
    # leapp if we do not remove them manually.  Not necessarily a bug per se,
    # but it is better if we go ahead and handle removing these packages before
    # starting leapp
    $self->_remove_obsolete_packages();

    return;
}

sub _remove_obsolete_packages ($self) {
    return unless Elevate::OS::needs_leapp();

    my @pkgs_to_remove = OBSOLETE_PACKAGES();
    $self->get_package_manager->remove(@pkgs_to_remove);
    return;
}

sub post_leapp ($self) {

    $self->run_once("_sysup");

    return;
}

sub _sysup ($self) {
    Cpanel::Yum::Vars::install();
    $self->get_package_manager->clean_all();

    unless ( Elevate::OS::is_apt_based() ) {
        my $epel_url = 'https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm';

        # no failures once already installed: no need to check for the epel-release version
        unless ( Cpanel::Pkgr::is_installed('epel-release') ) {
            $self->dnf->install_rpm_via_url($epel_url);
        }

        $self->dnf->config_manager_enable('powertools');
        $self->dnf->config_manager_enable('epel');
    }

    # Break cpanel-perl (NOTE: This only works on perl 5.36)
    unlink('/usr/local/cpanel/3rdparty/perl/536/cpanel-lib/X/Tiny.pm');
    {
        local $ENV{'CPANEL_BASE_INSTALL'} = 1;    # Don't fix more than perl itself.
        $self->ssystem(qw{/usr/local/cpanel/scripts/fix-cpanel-perl});
    }

    if ( Elevate::OS::is_apt_based() ) {
        $self->update_list_files();
        $self->apt->update();
    }

    $self->get_package_manager->update_allow_erasing( '--disablerepo', 'cpanel-plugins' );
    $self->ssystem_and_die(qw{/usr/local/cpanel/scripts/sysup});

    return;
}

sub update_list_files ($self) {
    my $list_dir = APT_LIST_D;

    opendir( my $dh, $list_dir ) or die "Unable to read directory $list_dir: $!\n";
    foreach my $list_file ( readdir($dh) ) {
        next unless $list_file =~ m{\.list$};
        $self->_update_list_file($list_file);
    }

    return;
}

sub _update_list_file ( $self, $list_file ) {
    my $list_dir         = APT_LIST_D;
    my $vetted_apt_lists = Elevate::OS::vetted_apt_lists();

    LOGDIE("Unknown list file: $list_dir/$list_file\n") unless exists $vetted_apt_lists->{$list_file};

    File::Slurper::write_binary( "$list_dir/$list_file", "$vetted_apt_lists->{$list_file}\n" );

    return;
}

1;
