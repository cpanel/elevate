package Elevate::Components::MountPoints;

=encoding utf-8

=head1 NAME

Elevate::Components::MountPoints

=head2 check

Verify that `mount -a` succeeds in order to confirm file system integrity
between reboots

=head2 pre_distro_upgrade

noop

=head2 post_distro_upgrade

noop

=cut

use cPstrict;

use parent qw{Elevate::Components::Base};

use constant FINDMNT_BIN => '/usr/bin/findmnt';
use constant MOUNT_BIN   => '/usr/bin/mount';

use Log::Log4perl qw(:easy);

sub check ($self) {
    $self->_ensure_mount_dash_a_succeeds();
    return;
}

sub _ensure_mount_dash_a_succeeds ($self) {

    # Only do this in start mode because it can change the file system mounts
    return if $self->is_check_mode();

    my $ret    = $self->ssystem_capture_output( MOUNT_BIN, '-a' );
    my $stderr = join "\n", @{ $ret->{stderr} };
    if ( $ret->{status} != 0 ) {

        # No use in letting leapp preupgrade execute if this fails
        $self->components->abort_on_first_blocker(1);

        my $bin = MOUNT_BIN();
        return $self->has_blocker( <<~"EOS");
        The following command failed to execute successfully on your server:

        $bin -a

        The following message was given as the reason for the failure:

        $stderr

        Since this script will need to reboot your server, we need to ensure a
        consistent file system in between in each reboot.  Please review the
        entries in '/etc/fstab' and ensure that each entry is valid and that
        '$bin -a' returns exit code 0 before continuing.

        If your '/etc/fstab' file has not been customized, you may want to
        consider reaching out to cPanel Support for assistance:
        https://docs.cpanel.net/knowledge-base/technical-support-services/how-to-open-a-technical-support-ticket/
        EOS
    }

    return;
}

1;
