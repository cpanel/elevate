package Perl::Critic::Policy::Cpanel::TryTinyUsage;

# cpanel - lib/Perl/Critic/Policy/Cpanel/TryTinyUsage.pm
#                                                  Copyright 2022 cPanel, L.L.C.
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

use strict;
use warnings;

use parent qw(Perl::Critic::Policy);

use Perl::Critic::Utils qw($SEVERITY_HIGH);

=head1 NAME

Perl::Critic::Policy::Cpanel::TryTinyUsage - Provides a Perl::Critic policy to check for
error-prone Try::Tiny usage.

=head1 SYNOPSIS

    $ perlcritic --single-policy Cpanel::CpanelExceptions script.pl
    $ perlcritic --single-policy Cpanel::CpanelExceptions lib/

=head1 DESCRIPTION

This policy ensures that invocations of Try::Tiny avoid the fully-qualified form with prototypes.

    Try::Tiny::try {
        ...
    } Try::Tiny::catch {
        ...
    } Try::Tiny::finally {
        ...
    };

=cut

our $VERSION = '0.01';
my $POLICY = 'DEVRFC-8: You must use the non-prototype form when invoking Try::Tiny in the fully-qualified form. Ex: Try::Tiny::try(sub { ... });';

sub default_severity {
    return $SEVERITY_HIGH;
}

sub applies_to {
    return 'PPI::Token::Word';
}

sub violates {
    my ( $self, $word ) = @_;

    return if $word->content !~ m/^Try::Tiny::(?:try|catch|finally)$/;

    my $arg = $word->snext_sibling();
    if ( $arg->isa('PPI::Structure::Block') ) {
        return $self->violation( 'Invalid Try::Tiny invocation', $POLICY, $arg );
    }

    return;
}

1;
