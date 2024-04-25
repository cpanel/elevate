package Perl::Critic::Policy::Cpanel::NoExitsFromSubroutines;

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use strict;
use warnings;

use parent qw(Perl::Critic::Policy);

use Perl::Critic::Utils qw($SEVERITY_HIGH :booleans);

=head1 NAME

Perl::Critic::Policy::Cpanel::NoExitsFromSubroutines - Provides a Perl::Critic policy to report unapproved exits from subroutines

=head1 SYNOPSIS

    $ perlcritic --single-policy Cpanel::NoExitsFromSubroutines script.pl
    $ perlcritic --single-policy Cpanel::NoExitsFromSubroutines lib/

=head1 DESCRIPTION

This policy ensures that exits from subroutines are reported. The policy is configurable to allow exits after certain function calls.

=cut

our $VERSION = '0.01';
my $POLICY = 'Cpanel::NoExitsFromSubroutines';

use constant MSG_FORMAT => 'Exit from subroutine detected%s. Please evaluate the usage of this exit and either refactor it away or add a ## no critic with why the exit remains.';

sub default_severity {
    return $SEVERITY_HIGH;
}

sub applies_to {
    return 'PPI::Statement::Sub';
}

sub violates {
    my ( $self, $elem ) = @_;

    my $allowed_hr = $self->{_allowed_after};
    my $words      = $elem->find('PPI::Token::Word');
    my $exit_element;
    my $allowed_because_after;
    for my $element (@$words) {
        $allowed_because_after = $element->content() if !$allowed_hr->{'none'} && $allowed_hr->{ $element->content() };
        next                                         if $element->content() ne 'exit';

        $exit_element = $element;
        last;    # Perl critic can only report on 1 violation per "applies_to"
    }

    if ( $exit_element && !$allowed_because_after ) {
        my $input_msg = $allowed_hr->{'none'} ? '' : ' not following ' . join( ' or ', sort keys %$allowed_hr );
        return $self->violation( sprintf( MSG_FORMAT(), $input_msg ), $POLICY, $exit_element );
    }

    return;
}

sub supported_parameters {
    return (
        {
            name                              => 'allowed_after',
            description                       => 'Subroutine exits will be allowed if called after the allowed_after method in the same subroutine.',
            default_string                    => 'none',
            behavior                          => 'enumeration',
            enumeration_values                => [qw{ none exec fork }],
            enumeration_allow_multiple_values => 1,
        },
    );
}

1;
