package Elevate::Blockers::JetBackup;

use cPstrict;

use Elevate::Constants ();

use parent qw{Elevate::Blockers::Base};

use Cpanel::Pkgr  ();
use Cwd           ();
use Log::Log4perl qw(:easy);

sub check ($self) {

    return $self->_blocker_old_jetbackup;
}

sub _blocker_old_jetbackup ($self) {

    return 0 unless $self->_use_jetbackup4_or_earlier();

    my $pretty_distro_name = $self->upgrade_to_pretty_name();

    return $self->has_blocker( <<~"END" );
    $pretty_distro_name does not support JetBackup prior to version 5.
    Please upgrade JetBackup before elevate.
    END

    return 0;
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
