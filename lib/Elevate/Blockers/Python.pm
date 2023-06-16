package Elevate::Blockers::Python;

=encoding utf-8

=head1 NAME

Elevate::Blockers::Python

Blocker to check if Conflicting python interpreters are installed.

=cut

use cPstrict;

use parent qw{Elevate::Blockers::Base};

use Cpanel::OS   ();
use Cpanel::Pkgr ();

sub check ($self) {

    # CL has packages which depend on the system Python 3, and it seems to work just fine.
    return if Cpanel::OS::is_cloudlinux();

    my $pkg = Cpanel::Pkgr::what_provides('python36');
    return unless $pkg && Cpanel::Pkgr::is_installed($pkg);
    return $self->has_blocker( <<~"END" );
    A package providing python36 has been detected as installed.
    This can interfere with the elevation process.
    Please remove it before elevation:
    yum remove $pkg
    END
}

1;
