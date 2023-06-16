package Elevate::Blockers::Distros;

=encoding utf-8

=head1 NAME

Elevate::Blockers::Distros

Blocker to check compatibility with current distribution.

=cut

use cPstrict;

use Cpanel::OS ();

use constant MINIMUM_CENTOS_7_SUPPORTED => 9;

use parent qw{Elevate::Blockers::Base};

use Log::Log4perl qw(:easy);

sub check ($self) {

    my @checks = qw{
      _blocker_is_non_centos7
      _blocker_is_old_centos7
      _blocker_is_experimental_os
    };

    foreach my $name (@checks) {
        my $blocker = $self->can($name)->($self);
        return $blocker if $blocker;
    }

    return 0;
}

# Fall back to an ad-hoc check if we don't get a defined value from can_be_elevated:
sub _distro_can_be_elevated () {
    return eval { Cpanel::OS::can_be_elevated() } // ( Cpanel::OS::distro() =~ m/^(?:centos|cloudlinux)$/ && Cpanel::OS::major() == 7 );
}

sub _blocker_is_non_centos7 ($self) {
    unless ( _distro_can_be_elevated() ) {
        my $pretty_distro_name = $self->upgrade_to_pretty_name();
        return $self->has_blocker(qq[This script is only designed to upgrade CentOS/CloudLinux 7 to $pretty_distro_name.]);
    }

    return 0;
}

sub _blocker_is_old_centos7 ($self) {
    if ( Cpanel::OS::minor() < MINIMUM_CENTOS_7_SUPPORTED ) {
        my $pretty_distro_name = $self->upgrade_to_pretty_name();
        return $self->has_blocker(
            sprintf(
                'You need to run CentOS/CloudLinux 7.%s and later to upgrade to %s. You are currently using %s',    #
                MINIMUM_CENTOS_7_SUPPORTED, $pretty_distro_name, Cpanel::OS::display_name()           #
            )
        );
    }

    return 0;
}

sub _blocker_is_experimental_os ($self) {
    if ( -e '/var/cpanel/caches/Cpanel-OS.custom' ) {
        return $self->has_blocker('Experimental OS detected. This script only supports CentOS 7 upgrades');
    }

    return 0;
}

sub bail_out_on_inappropriate_distro () {

    unless ( _distro_can_be_elevated() ) {
        FATAL(qq[This script is designed to only run on CentOS or CloudLinux 7 servers.\n]);
        exit 1;
    }

    return;
}

1;
