package Elevate::Blockers::JetBackup;

=encoding utf-8

=head1 NAME

Elevate::Blockers::JetBackup

Blocker to check if JetBackup is supported.

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::OS        ();

use parent qw{Elevate::Blockers::Base};

use Cpanel::Pkgr  ();
use Cwd           ();
use Log::Log4perl qw(:easy);

sub check ($self) {

    $self->_blocker_jetbackup_is_supported();
    $self->_blocker_old_jetbackup();

    return;
}

sub _blocker_jetbackup_is_supported ($self) {
    return unless Cpanel::Pkgr::is_installed('jetbackup');
    return if Elevate::OS::supports_jetbackup();

    my $name = Elevate::OS::default_upgrade_to();
    $self->has_blocker( <<~"END" );
    ELevate does not currently support JetBackup for upgrades of $name.
    Support for JetBackup on Ubuntu will be added in a future version of ELevate.
    END

    return;
}

sub _blocker_old_jetbackup ($self) {

    return 0 unless $self->_use_jetbackup4_or_earlier();

    my $pretty_distro_name = Elevate::OS::upgrade_to_pretty_name();

    return $self->has_blocker( <<~"END" );
    $pretty_distro_name does not support JetBackup prior to version 5.
    Please upgrade JetBackup before elevate.
    END

}

sub _use_jetbackup4_or_earlier ($self) {
    return unless Cpanel::Pkgr::is_installed('jetbackup');
    my $v = Cpanel::Pkgr::get_package_version("jetbackup");

    if ( defined $v && $v =~ qr{^[1-4]\b} ) {
        WARN("JetBackup version $v currently installed.");
        return 1;
    }

    return;
}

1;
