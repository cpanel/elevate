#!/usr/local/cpanel/3rdparty/bin/perl
# HARNESS-DURATION-LONG

use FindBin;
use lib $FindBin::Bin . "/lib";

my $bin          = $FindBin::Bin;
my $perlcriticrc = $bin . '.perlcriticrc';

use Test::Perl::Critic -profile => $perlcriticrc;

my $script_dir = $bin . '/..' . '/script';
my $lib_dir    = $bin . '/..' . '/lib';

all_critic_ok( $script_dir, $lib_dir );

1;
