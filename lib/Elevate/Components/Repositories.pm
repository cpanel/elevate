package Elevate::Components::Repositories;

=encoding utf-8

=head1 NAME

Elevate::Components::Repositories

Disable some repostiories.

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::OS        ();
use Elevate::RPM       ();

use Cpanel::SafeRun::Simple ();
use Cwd                     ();
use File::Copy              ();
use Log::Log4perl           qw(:easy);

use parent qw{Elevate::Components::Base};

sub pre_distro_upgrade ($self) {

    $self->run_once("_disable_yum_plugin_fastestmirror");
    $self->run_once("_disable_known_yum_repositories");

    return;
}

sub _disable_known_yum_repositories {

    # remove all MySQL repos
    my @repo_files = map { Elevate::Constants::YUM_REPOS_D . '/' . $_ } Elevate::OS::disable_mysql_yum_repos();

    foreach my $f (@repo_files) {
        next unless -e $f;
        if ( -l $f ) {
            unlink $f;
            next;
        }

        File::Copy::move( $f, "$f.off" ) or die qq[Failed to disable repo $f];
    }

    Cpanel::SafeRun::Simple::saferunnoerror(qw{/usr/bin/yum clean all});

    return;
}

sub _disable_yum_plugin_fastestmirror ($self) {
    my $pkg = 'yum-plugin-fastestmirror';
    $self->_erase_package($pkg);
    return;
}

sub _erase_package ( $self, $pkg ) {
    return unless Cpanel::Pkgr::is_installed($pkg);
    $self->rpm->remove_no_dependencies($pkg);
    return;
}

1;
