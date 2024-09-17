package Elevate::Blockers::BootKernel;

=encoding utf-8

=head1 NAME

Elevate::Blockers::BootKernel

Blocker to determine whether the running kernel is the same one configured for
boot. This is being used as a proxy for determining whether the system has any
control over which kernel and initrd is booted via GRUB, which is necessary for
leapp to function.

=cut

use cPstrict;

use parent qw{Elevate::Blockers::Base};

use Elevate::Constants ();

use Cpanel::Kernel::Status ();
use Cpanel::Exception      ();
use Cpanel::YAML           ();
use Cpanel::JSON           ();

use Try::Tiny;

sub check ($self) {

    return 1 unless $self->should_run_distro_upgrade;    # skip when --upgrade-distro-manually is provided

    my $ok = 0;
    try {
        my ( $running_version, $boot_version ) = Cpanel::Kernel::Status::reboot_status()->@{ 'running_version', 'boot_version' };
        $ok = $running_version eq $boot_version;

        $self->has_blocker( <<~EOS ) if !$ok;
        The running kernel version ($running_version) does not match that of
        the default boot entry ($boot_version). This could be due to the kernel
        being changed by an update, meaning that a reboot should resolve this.
        However, this also could indicate that the system does not have control
        over which kernel and early boot environment (initrd) is used upon
        reboot, which is required to upgrade the operating system with this
        script.

        If this message remains after a reboot, your server may have been
        configured to boot into a particular kernel directly rather than to an
        instance of the GRUB2 boot loader. This often happens to virtualized
        servers, but physical servers also can have this problem under certain
        configurations. Your provider may have a solution to allow booting into
        GRUB2; contact them for further information.
        EOS
    }
    catch {
        my $ex = $_;
        $self->has_blocker(
            "Unable to determine running and boot kernels due to the following error:\n"    #
              . _to_str($ex)
        );
    };

    return $ok ? 1 : 0;
}

sub _to_str ($e) {
    $e //= '';

    my $str = Cpanel::Exception::get_string($e);

    if ( length $str ) {

        # can return a YAML or JSON object... handle both
        my $hash = eval { Cpanel::YAML::Load($str) }    # parse yaml
          // eval { Cpanel::JSON::Load($str) }          # or json output... we cannot predict
          // {};
        if ( ref $hash eq 'HASH' && $hash->{msg} ) {
            $str = $hash->{msg};
        }
    }

    return $str;
}

1;
