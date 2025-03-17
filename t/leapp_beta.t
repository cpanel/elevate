#!/usr/local/cpanel/3rdparty/bin/perl

# HARNESS-NO-STREAM

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use cPstrict;
use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockModule qw/strict/;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;

$INC{'scripts/ElevateCpanel.pm'} = '__TEST__';

my @ssystem_cmds;
my $leappbeta    = 1;
my $mock_elevate = Test::MockModule->new('cpev');
$mock_elevate->redefine(
    ssystem_and_die => sub ( $, @args ) {

        push @ssystem_cmds, [@args];
        note "run: " . join( " ", @args );

        return;
    },
    getopt => sub ( $, $opt ) { return $leappbeta if $opt && $opt eq 'leappbeta' },
);

my $cpev = bless( {}, 'cpev' );
my $self = Elevate::Leapp->new( 'cpev' => $cpev );

set_os_to_cloudlinux_7();
is( $self->beta_if_enabled, 1,                                                                                                                           "beta_if_enabled when enabled" );
is( \@ssystem_cmds,         [ [qw{/usr/bin/yum-config-manager --disable cloudlinux-elevate}], [qw{/usr/bin/yum-config-manager --enable cloudlinux-elevate-updates-testing}] ], "Expected commands are run to setup the repos." )
  or diag explain \@ssystem_cmds;

$leappbeta    = 0;
@ssystem_cmds = ();
is( $self->beta_if_enabled, undef, "beta_if_enabled when disabled" );
is( \@ssystem_cmds,         [],    "No commands are run to setup the repos." );

done_testing;
