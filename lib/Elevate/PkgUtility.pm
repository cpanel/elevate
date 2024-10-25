package Elevate::PkgUtility;

=encoding utf-8

=head1 NAME

Elevate::PkgUtility

Generic parent class for the logic wrapping the systems package utilities such
as rpm and dpkg

=cut

use cPstrict;

use Elevate::PkgUtility::RPM ();

our $PKGUTILITY;

sub factory {

    my $pkg = 'Elevate::PkgUtility::' . Elevate::OS::package_utility();
    return $pkg->new;
}

sub instance {
    $PKGUTILITY //= factory();
    return $PKGUTILITY;
}

sub name () {
    return instance()->name();
}

1;
