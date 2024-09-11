package Elevate::Components::ELS;

=encoding utf-8

=head1 NAME

Elevate::Components::ELS

Remove ELS for CentOS 7

=cut

use cPstrict;

use Elevate::OS ();

use Cpanel::Pkgr  ();
use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

use constant ELS_PACKAGE => 'els-define';

sub pre_distro_upgrade ($self) {

    return unless Elevate::OS::remove_els();

    my @files_to_remove = qw{
      /etc/yum.repos.d/centos7-els.repo
      /etc/yum.repos.d/centos7-els-rollout.repo
    };

    foreach my $file (@files_to_remove) {
        if ( -e $file ) {
            unlink $file or WARN("Could not remove file $file: $!");
        }
    }

    $self->yum->remove(ELS_PACKAGE) if Cpanel::Pkgr::is_installed(ELS_PACKAGE);

    return;
}

sub post_distro_upgrade ($self) {

    # Nothing to do
    return;
}

1;
