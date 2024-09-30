#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use cPstrict;

note 'Fatpacking elevate-cpanel';
system(qw{make --quiet build}) and die "Failed to fatpack elevate-cpanel\n";

note 'Checking git status';
my $status = `git status --short`;
my @lines  = split "\n", $status;
@lines = grep { $_ !~ /^\s*$/ } @lines;

is( scalar @lines, 0, 'git status returned cleanly' ) or do {
    diag explain \@lines;
    diag "Diff for modified files:";
    diag `git diff`;
};

done_testing();
