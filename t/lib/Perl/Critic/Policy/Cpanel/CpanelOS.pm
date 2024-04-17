package Perl::Critic::Policy::Cpanel::CpanelOS;

# cpanel - lib/Perl/Critic/Policy/Cpanel/CpanelOS.pm
#                                                  Copyright 2022 cPanel, L.L.C.
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

use strict;
use warnings;

use parent qw(Perl::Critic::Policy);

use Perl::Critic::Utils qw{ :severities :classification :ppi $SEVERITY_MEDIUM $TRUE $FALSE };

=head1 NAME Perl::Critic::Policy::Cpanel::CpanelOS - Detect discouraged Cpanel::OS calls

=head1 SYNOPSIS

    $ perlcritic --single-policy Cpanel::CpanelOS script.pl
    $ perlcritic --single-policy Cpanel::CpanelOS lib/

=head1 DESCRIPTION

This policy detects discouraged calls of Cpanel::OS methods/functions.

=over

=item Cpanel::OS::_instance

=item Cpanel::OS::build

=item  Cpanel::OS::distro

=item Cpanel::OS::major

=item Cpanel::OS::minor

=item Cpanel::OS::is_apt_based

=back

=cut

our $VERSION = '0.02';

use constant POLICY => q[You should avoid calling these Cpanel::OS methods. Please consider using a more generic question.];

use constant NOT_RECOMMENDED_METHODS => qw{
  _instance
  build
  distro
  is_apt_based
  major
  minor
};

use constant default_severity => $SEVERITY_HIGH;
use constant applies_to       => 'PPI::Token::Word';
use constant default_themes   => qw{cpanel};

sub initialize_if_enabled {
    my ( $self, $config ) = @_;

    my $list = join( '|', NOT_RECOMMENDED_METHODS );

    $self->{_regexp} = qr/^Cpanel::OS::(?:$list)$/;

    return $TRUE;
}

sub violates {
    my ( $self, $elem ) = @_;

    return unless defined $self->{_regexp};

    return if is_hash_key($elem);

    if ( is_method_call($elem) && grep { $_ eq $elem } NOT_RECOMMENDED_METHODS ) {

        my $prev_m1 = eval { $elem->previous_token }    or return;
        my $prev_m2 = eval { $prev_m1->previous_token } or return;

        if ( $prev_m2 eq 'Cpanel::OS' ) {
            return $self->violation( 'Discouraged Cpanel::OS method call:' => POLICY, $elem );
        }

        return;
    }
    elsif ( $elem =~ $self->{_regexp} ) {
        return $self->violation( 'Discouraged Cpanel::OS call: ' => POLICY, $elem );
    }

    return;
}

1;
