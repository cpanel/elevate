package Perl::Critic::Policy::TryTiny::ProhibitExitingSubroutine;

# cpanel - lib/Perl/Critic/Policy/TryTiny/ProhibitExitingSubroutine.pm
#                                                  Copyright 2022 cPanel, L.L.C.
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

use strict;
use warnings;
use utf8;

our $VERSION = '0.003';

use Readonly;
use Perl::Critic::Utils qw( :severities :classification :ppi );

use parent 'Perl::Critic::Policy';

# ABSTRACT: Ban next/last/return in Try::Tiny blocks
Readonly::Scalar my $DESC => "Using next/last/redo/return in a Try::Tiny block is ambiguous";
Readonly::Scalar my $EXPL => "Using next/last/redo without a label or using return in a Try::Tiny block is ambiguous, did you intend to exit out of the try/catch/finally block or the surrounding block?";

sub supported_parameters {
    return ();
}

sub default_severity {
    return $SEVERITY_HIGH;
}

sub default_themes {
    return qw(bugs);
}

sub prepare_to_scan_document {
    my $self     = shift;
    my $document = shift;

    return $document->find_any(
        sub {
            my $element = $_[1];
            return 0 if !$element->isa('PPI::Statement::Include');
            my @children = grep { $_->significant } $element->children;
            if ( $children[1] && $children[1]->isa('PPI::Token::Word') && $children[1] eq 'Try::Tiny' ) {
                return 1;
            }
            return 0;
        }
    );
}

sub applies_to {
    return 'PPI::Token::Word';
}

sub violates {
    my ( $self, $elem, undef ) = @_;

    return if $elem->content ne 'try';
    return if !is_function_call($elem);

    my @blocks_to_check;

    if ( my $try_block = $elem->snext_sibling() ) {
        if ( $try_block->isa('PPI::Structure::Block') ) {
            push @blocks_to_check, $try_block;
        }
        my $sib = $try_block->snext_sibling();
        if ( $sib and $sib->content eq 'catch' and my $catch_block = $sib->snext_sibling() ) {
            if ( $catch_block->isa('PPI::Structure::Block') ) {
                push @blocks_to_check, $catch_block;
            }
            $sib = $catch_block->snext_sibling();
        }
        if ( $sib and $sib->content eq 'finally' and my $finally_block = $sib->snext_sibling() ) {
            if ( $finally_block->isa('PPI::Structure::Block') ) {
                push @blocks_to_check, $finally_block;
            }
        }
    }

    for my $block_to_check (@blocks_to_check) {
        my $violation = $self->_check_block($block_to_check);
        if ( defined($violation) ) {
            return $violation;
        }
    }
    return;
}

sub _check_block {
    my $self  = shift;
    my $block = shift;

    my $violation;

    my $wanted;
    $wanted = sub {
        my ( $parent, $element, $in_loop, $in_sub_block ) = @_;
        $in_loop      //= 0;
        $in_sub_block //= 0;

        if ( $element->isa('PPI::Statement::Compound') ) {
            if ( $element->type eq 'for' || $element->type eq 'foreach' || $element->type eq 'while' ) {
                my ($subblock) = grep { $_->isa('PPI::Structure::Block') } $element->schildren;
                $subblock->find_any( sub { $wanted->( @_, 1, $in_sub_block ) } );
                return undef;
            }
        }
        elsif ( $element->isa("PPI::Structure::Block") ) {
            my $prev_sib = $element->sprevious_sibling;
            if ( $prev_sib && $prev_sib->isa("PPI::Token::Word") && $prev_sib eq 'sub' ) {
                $element->find_any( sub { $wanted->( @_, $in_loop, 1 ) } );
                return undef;
            }
        }
        elsif ( $element->isa('PPI::Token::Word') ) {
            if ( $element eq 'return' && !$in_sub_block ) {
                $violation = $self->violation( $DESC, $EXPL, $element );
                return 1;
            }

            my $sib = $element->snext_sibling;

            if ( $element eq 'next' || $element eq 'redo' || $element eq 'last' ) {
                if ( !$in_loop && ( !$sib || !_is_label($sib) ) ) {
                    $violation = $self->violation( $DESC, $EXPL, $element );
                    return 1;
                }
            }
        }
    };
    $block->find_any($wanted);

    return $violation;
}

sub _is_label {
    my $element = shift;

    if ( $element eq 'if' || $element eq 'unless' ) {
        return 0;
    }

    return $element =~ /^[_a-z]+$/i ? 1 : 0;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Perl::Critic::Policy::TryTiny::ProhibitExitingSubroutine - Ban next/last/return in Try::Tiny blocks

=head1 VERSION

version 0.002

=head1 DESCRIPTION

Take this code:

    use Try::Tiny;

    for my $item (@array) {
        try {
            next if $item == 2;
            # other code
        }
        catch {
            warn $_;
        };
        # other code
    }

The next statement will not go to the next iteration of the for-loop, rather,
it will exit the try block, emitting a warning if warnings are enabled.

This is probably not what the developer had intended, so this policy prohibits it.

One way to fix this is to use labels:

    use Try::Tiny;

    ITEM:
    for my $item (@array) {
        try {
            if ($item == 2) {
                no warnings 'exiting';
                next ITEM;
            }
            # other code
        }
        catch {
            warn $_;
        };
        # other code
    }

=head1 CONFIGURATION

This Policy is not configurable except for the standard options.

=head1 KNOWN BUGS

This policy assumes that L<Try::Tiny> is being used, and it doesn't run if it
can't find it being imported.

=head1 AUTHOR

David D Lowe <flimm@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Lokku <cpan@lokku.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
