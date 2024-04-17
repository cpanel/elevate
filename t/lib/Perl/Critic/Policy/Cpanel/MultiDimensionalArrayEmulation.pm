package Perl::Critic::Policy::Cpanel::MultiDimensionalArrayEmulation;

# cpanel - lib/Perl/Critic/Policy/Cpanel/MultiDimensionalArrayEmulation.pm
#                                                  Copyright 2022 cPanel, L.L.C.
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

use strict;
use warnings;

use parent qw(Perl::Critic::Policy);

use Perl::Critic::Utils qw($SEVERITY_HIGH);

=head1 NAME

Perl::Critic::Policy::Cpanel::MultiDimensionalArrayEmulation - Provides a Perl::Critic policy to report invalid multidimensional hash keys

=head1 SYNOPSIS

    $ perlcritic --single-policy Cpanel::MultiDimensionalArrayEmulation script.pl
    $ perlcritic --single-policy Cpanel::MultiDimensionalArrayEmulation lib/

=head1 DESCRIPTION

This policy ensures that multi-value hash keys are reported when they are used in non-"hash slice" expressions. E.g. $foo{1,2} vs @foo{1,2}

=cut

our $VERSION = '0.01';
my $POLICY = 'Cpanel::MultiDimensionalArrayEmulation';

use constant MSG_FORMAT => 'Use of multidimensional array emulation detected. You probably wanted @var%2$s{%1$s} instead of $var%2$s{%1$s}.';

sub default_severity {
    return $SEVERITY_HIGH;
}

sub applies_to {
    return 'PPI::Statement';
}

sub violates {
    my ( $self, $elem ) = @_;

    if ( my @children = $self->_get_children_no_whitespace($elem) ) {

        # First block is trying to match ${a}{ ... } where ... could be like {'x', 'y'} or {qw( x y )}
        #   PPI::Statement
        #     PPI::Token::Cast  	'$'
        #     PPI::Structure::Block  	{ ... }
        #     PPI::Statement
        #         PPI::Token::Symbol  	'$a'
        #     PPI::Structure::Subscript  	{ ... }
        #     PPI::Statement::Expression
        #         PPI::Token::Quote::Single  	''x''
        #         PPI::Token::Operator  	','
        #         PPI::Token::Quote::Single  	''y''
        if ( $children[0]->isa('PPI::Token::Cast') && $children[0] eq '$' ) {    # ${$a}{'x','y'} <-- the ${} is considered a Cast -- @{} is ok
            shift @children;                                                     # Remove the cast
            return if !$children[0]->isa('PPI::Structure::Block');               # matching {$a}{'x','y'}
            my $block_elem = shift @children;                                    # taking {$a}, leaving {'x','y'}
            if ( my ($child) = $self->_get_children_no_whitespace($block_elem) ) {
                return if !$child->isa('PPI::Statement');                        # Statement containing $a
                my ($statement) = $self->_get_children_no_whitespace($child);    # Now just $a

                return if !$statement->isa('PPI::Token::Symbol');
                unshift @children, $statement;                                   #put $a back at the beginning, so now $a{'x','y'}
            }
        }
        elsif ( !$children[0]->isa('PPI::Token::Symbol') ) {
            return;
        }

        # [@$]a(?:->)?{ ... } at this point
        my $sigil = substr( $children[0], 0, 1 );
        return if $sigil eq '@';    # No known issues can happen when the sigil is '@'

        # Now we're operating on $a(?:->)?{ ... }
        my ( $subscript_element, $used_arrow ) = $self->_find_subscript_in_children( \@children );
        return if !$subscript_element;

        return $self->_has_violating_pattern( $elem, $subscript_element, $used_arrow );
    }

    return;
}

sub _has_violating_pattern {
    my ( $self, $parent_element, $subscript_element, $used_arrow ) = @_;

    my @children = $self->_get_children_no_whitespace($subscript_element);
    return if !$children[0] || !$children[0]->isa('PPI::Statement::Expression');

    my $expression_element = $children[0];
    my $arrow_char         = ( $used_arrow ? '->' : '' );
    @children = $self->_get_children_no_whitespace( $children[0] );

    # subscript starts w/ function call like substr, sprintf, or join. These are the 3 examples I saw in our codebase
    return if !$children[0] || $children[0]->isa('PPI::Token::Word');    # this may need to be further refined as this may allow unknown bad usage

    if ( $children[0]->isa('PPI::Token::QuoteLike::Words') ) {
        return $self->violation( sprintf( MSG_FORMAT, "$children[0]", $arrow_char ), $POLICY, $parent_element );
    }

    if ( my @operators = grep { $_->isa('PPI::Token::Operator') } @children ) {
        if ( grep { $_ eq ',' || $_ eq '=>' } @operators ) {
            return $self->violation( sprintf( MSG_FORMAT, "$expression_element", $arrow_char ), $POLICY, $parent_element );
        }
    }

    return;
}

sub _find_subscript_in_children {
    my ( $self, $children_ar ) = @_;

    # Element 0 already checked otherwise we wouldn't be in this function
    if ( $children_ar->[1] && $children_ar->[1]->isa('PPI::Token::Operator') && $children_ar->[1] eq '->' ) {    # $a->{1,2}
        return if !$children_ar->[2]->isa('PPI::Structure::Subscript');

        return ( $children_ar->[2], 1 );
    }
    elsif ( $children_ar->[1] && $children_ar->[1]->isa('PPI::Structure::Subscript') ) {                         # $a{1,2}
        return ( $children_ar->[1], 0 );
    }

    return;
}

sub _get_children_no_whitespace {
    my ( $self, $elem ) = @_;

    return grep { !$_->isa('PPI::Token::Whitespace') } $elem->children();
}

1;
