#!/usr/local/cpanel/3rdparty/bin/perl

# cpanel - ./t/blockers.t                          Copyright 2022 cPanel, L.L.C.
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockFile qw/strict/;
use Test::MockModule qw/strict/;

use cPstrict;
require $FindBin::Bin . '/../elevate-cpanel';

my $cpev_mock = Test::MockModule->new('cpev');
my @messages_seen;
$cpev_mock->redefine( '_msg' => sub { my ( $type, $msg ) = @_; push @messages_seen, [ $type, $msg ]; return } );

{
    no warnings 'once';
    local $Cpanel::Version::Tiny::major_version;
    is( cpev::blockers_check(), 1, "no major_version means we're not cPanel?" );
    message_seen( 'ERROR', 'Invalid cPanel & WHM major_version' );

    $Cpanel::Version::Tiny::major_version = 98;
    is( cpev::blockers_check(), 2, "11.98 is unsupported for this script." );
    message_seen( 'ERROR', qr/This version 11\.\d+\.\d+\.\d+ does not support upgrades to AlmaLinux 8. Please upgrade to cPanel version 102 or better/a );
}

#my $mock_saferun = Test::MockModule->new('Cpanel::SafeRun::Simple');
#$mock_saferun->redefine(
#    saferunnoerror => sub {
#        $saferun_output;
#    }
#);

done_testing();

sub message_seen ( $type, $msg ) {
    my $line = shift @messages_seen;
    if ( ref $line ne 'ARRAY' ) {
        fail("    No message of type '$type' was emitted.");
        fail("    With output: $msg");
        return 0;
    }

    my $type_seen = $line->[0] // '';
    $type_seen =~ s/^\s+//;
    $type_seen =~ s/: //;

    is( $type_seen, $type, "  |_  Message type is $type" );
    if ( ref $msg eq 'Regexp' ) {
        like( $line->[1], $msg, "  |_  Message string is expected." );
    }
    else {
        is( $line->[1], $msg, "  |_  Message string is expected." );
    }

    return;
}
