package Elevate::Blockers::Python;

=encoding utf-8

=head1 NAME

Elevate::Blockers::Python

Blocker to check if Conflicting python interpreters are installed.

=cut

use cPstrict;

use parent qw{Elevate::Blockers::Base};

use Cpanel::Pkgr  ();

sub check ($self) {
    my $pkg = Cpanel::Pkgr::what_provides('python36');
    return unless $pkg && Cpanel::Pkgr::is_installed($pkg);
    return $self->has_blocker( <<~"END" );
    python36 packages have been detected as installed.
    These can interfere with the elevation process.
    Please remove these packages before elevation:
    yum remove python36*
    END
}

1;
