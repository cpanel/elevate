package Perl::Critic::Policy::Cpanel::CpanelExceptions;

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use strict;
use warnings;

use parent qw(Perl::Critic::Policy);

use Perl::Critic::Utils qw($SEVERITY_HIGH);

=head1 NAME

Perl::Critic::Policy::Cpanel::CpanelExceptions - Provides a Perl::Critic policy to ensure proper Cpanel::Exception usage

=head1 SYNOPSIS

    $ perlcritic --single-policy Cpanel::CpanelExceptions script.pl
    $ perlcritic --single-policy Cpanel::CpanelExceptions lib/

=head1 DESCRIPTION

This policy ensures that invocations of Cpanel::Exception always pass parameters in an ARRAYREF.

=cut

our $VERSION = '0.01';
my $POLICY = 'Cpanel::Exception Usage';

sub default_severity {
    return $SEVERITY_HIGH;
}

sub applies_to {
    return 'PPI::Token::Word';
}

sub violates {
    my ( $self, $word ) = @_;

    return if $word->content ne 'Cpanel::Exception::create';

    my $list = $word->snext_sibling();
    if ( my $param_list = $list->find_first('PPI::Structure::Constructor') ) {
        return $self->violation( 'Use ARRAYREFs for parameters', $POLICY, $param_list )
          if $param_list->braces() ne '[]';
    }

    return;
}

1;
