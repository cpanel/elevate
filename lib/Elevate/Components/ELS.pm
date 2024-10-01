package Elevate::Components::ELS;

=encoding utf-8

=head1 NAME

Elevate::Components::ELS

=head2 check

noop

=head2 pre_distro_upgrade

Remove ELS repo files and ELS specific package

=head2 post_distro_upgrade

noop

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

1;
