package Perl::Critic::Policy::Cpanel::TransliterationUsage;

# cpanel - lib/Perl/Critic/Policy/Cpanel/TransliterationUsage.pm
#                                                  Copyright 2022 cPanel, L.L.C.
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

use strict;
use warnings;

use parent qw(Perl::Critic::Policy);

use Perl::Critic::Utils qw($SEVERITY_HIGH);

=head1 NAME

Perl::Critic::Policy::Cpanel::TransliterationUsage - Provides a Perl::Critic policy to ensure proper tr/// usage

=head1 SYNOPSIS

    $ perlcritic --single-policy Cpanel::TransliterationUsage script.pl
    $ perlcritic --single-policy Cpanel::TransliterationUsage lib/

=head1 DESCRIPTION

This policy ensures that invocations of tr/// do not include attempted character classes like tr/[A-Z]/[a-z]/

=cut

our $VERSION = '0.02';
my $POLICY = 'Cpanel::TransliterationUsage Usage';

sub default_severity {
    return $SEVERITY_HIGH;
}

sub applies_to {
    return 'PPI::Token::Regexp::Transliterate';
}

sub violates {
    my ( $self, $tr_usage ) = @_;

    if ( _is_regex_character_class( $tr_usage->get_match_string() ) || _is_regex_character_class( $tr_usage->get_substitute_string() ) ) {
        return $self->violation( 'Character class, e.g. tr/[A-Z]/[a-z]/, used in transliteration. Use just tr/A-Z/a-z/ instead.', $POLICY, $tr_usage );
    }

    return;
}

# We only care if it's a regex character class
sub _is_regex_character_class {
    my ($string) = @_;

    if ( index( $string, '[' ) == 0 && rindex( $string, ']' ) == ( length($string) - 1 ) && $string =~ /[0-9A-Za-z]-[0-9A-Za-z]/ ) {
        return 1;
    }

    return 0;
}

1;
