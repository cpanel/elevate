package Elevate::PkgUtility::Base;

=encoding utf-8

=head1 NAME

Elevate::PkgUtility::Base

This is a base class used by Elevate::PkgUtility::*

=cut

use cPstrict;

use parent 'Elevate::Roles::Run';

sub new ( $class, $opts = undef ) {
    $opts //= {};

    my $self = {%$opts};
    bless $self, $class;

    return $self;
}

sub name ($self) { die "name unimplemented" }

1;
