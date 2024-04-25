package Perl::Critic::Policy::Cpanel::ProhibitQxAndBackticks;

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use strict;
use warnings;

use parent qw(Perl::Critic::Policy);

use Perl::Critic::Utils qw($SEVERITY_HIGH);

=head1 NAME

Perl::Critic::Policy::Cpanel::ProhibitQxAndBackticks - Provides a Perl::Critic policy to prohibit shell unsafe qx and `` operators along with their backing readpipe operator

=head1 SYNOPSIS

    $ perlcritic --single-policy Cpanel::ProhibitQxAndBackticks script.pl
    $ perlcritic --single-policy Cpanel::ProhibitQxAndBackticks lib/

=head1 DESCRIPTION

This policy prohibits the usage of qx or the backticks (``) operators as well as their backing readpipe function. Do not add new usages.

=cut

our $VERSION = '0.01';

use constant {
    DESC => q{Use of qx, backticks, or readpipe},
    EXPL => q{Use Cpanel::SafeRun::Object instead}
};

sub default_severity {
    return $SEVERITY_HIGH;
}

sub applies_to {
    return qw( PPI::Token::QuoteLike::Backtick PPI::Token::QuoteLike::Command PPI::Statement );
}

sub violates {
    my ( $self, $elem, undef ) = @_;

    if ( index( $elem->class(), 'PPI::Statement' ) == 0 ) {
        my $words = $elem->find('PPI::Token::Word');
        return if 'ARRAY' ne ref $words;
        my $readpipe_element;
        for my $element (@$words) {
            next if $element->content() ne 'readpipe';

            $readpipe_element = $element;
            last;    # Perl critic can only report on 1 violation per "applies_to"
        }

        return if !$readpipe_element;

        return $self->violation( DESC(), EXPL(), $readpipe_element );
    }
    else {
        return $self->violation( DESC(), EXPL(), $elem );
    }
}

1;
