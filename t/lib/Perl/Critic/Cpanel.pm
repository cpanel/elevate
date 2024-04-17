package Perl::Critic::Cpanel;

# cpanel - lib/Perl/Critic/Cpanel.pm               Copyright 2022 cPanel, L.L.C.
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

use strict;
use warnings;

=head1 NAME

Perl::Critic::Cpanel - Perl::Critic policies for cPanel & WHM

=cut

our $VERSION = '0.12';

=head1 SYNOPSIS

    $ perlcritic --single-policy Cpanel::CpanelExceptions script.pl
    $ perlcritic --single-policy Cpanel::CpanelExceptions lib/

=head1 DESCRIPTION

A set of Perl::Critic policies to enforce the coding standards of cPanel & WHM.

=head1 POLICIES

=head2 Perl::Critic::Policy::Cpanel::CpanelExceptions

Use array references as parameters instead of hash references when invoking C<Cpanel::Exception>.

=head2 Perl::Critic::Policy::Cpanel::MultiDimensionalArrayEmulation

Hash keys should not be multi-valued outside of a hash slice.

=head2 Perl::Critic::Policy::Cpanel::ProhibitQxAndBackticks

Prohibit qx and backticks.

=head2 Perl::Critic::Policy::Cpanel::TransliterationUsage

Invocations of C<tr///> do not include attempted character classes like tr/[A-Z]/[a-z]/

=head2 Perl::Critic::Policy::Cpanel::TryTinyUsage

Invocations of L<Try::Tiny> should avoid the fully-qualified form with prototypes.

=head2 Perl::Critic::Policy::TryTiny::ProhibitExitingSubroutine

Fork of the L<TryTiny::ProhibitExitingSubroutine> policy from the "Lokku" critic-package.

Our fork currently has the following bug fixes:

=over 2

=item *

CPANEL-14429: Ensure that the policy does not flag 'last/next/redo'
statements within C<while> loops.

=item *

Ensure the policy properly checks C<finally> blocks (bug noticed while fixing CPANEL-14429).

=back

The L<Perl::Critic::Lokku> package is abandoned, and since this is the only policy we use from
that package, we are forking and maintaining it.

=cut

1;
