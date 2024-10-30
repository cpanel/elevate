package Elevate::Components::Kernel;

=encoding utf-8

=head1 NAME

Elevate::Components::Kernel

=head2 check

noop

=head2 pre_distro_upgrade

noop

=head2 post_distro_upgrade

Check and notify of installed el7 kernel packages

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::OS        ();
use Elevate::PkgMgr    ();

use Cwd           ();
use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

sub post_distro_upgrade ($self) {

    $self->run_once('_kernel_check');

    return;
}

sub _kernel_check ($self) {

    my @kernel_rpms = Elevate::PkgMgr::get_installed_pkgs();
    @kernel_rpms = sort grep { m/^kernel-\S+el7/ } @kernel_rpms;

    return unless @kernel_rpms;
    chomp @kernel_rpms;

    my $pretty_distro_name = Elevate::OS::upgrade_to_pretty_name();

    my $msg = "The following kernels should probably be removed as they will not function on $pretty_distro_name:\n\n";
    foreach my $kernel (@kernel_rpms) {
        $msg .= "    $kernel\n";
    }

    $msg .= "\nYou can remove these by running: /usr/bin/rpm -e " . join( " ", @kernel_rpms ) . "\n";

    Elevate::Notify::add_final_notification($msg);

    return;
}

1;
