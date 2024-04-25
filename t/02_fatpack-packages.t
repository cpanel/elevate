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

use lib $FindBin::Bin . "/lib", $FindBin::Bin . "/../lib";

use File::Find    ();
use File::Slurper ();

my @packages = _get_packages_from_lib();

my $elevate_script         = $FindBin::Bin . "/../elevate-cpanel";
my $elevate_script_content = File::Slurper::read_binary($elevate_script);

foreach my $package (@packages) {
    ok $elevate_script_content =~ qr{^ \s+ package \s+ $package;}xms, "$package is fatpack'd in elevate-cpanel script";
}

done_testing;
exit;

sub _get_packages_from_lib ( $root = undef ) {

    $root //= $FindBin::Bin . "/../lib";

    my @list;

    my $process = sub {

        my $name = $File::Find::name;
        return unless -f $name;
        return unless $name =~ s{\.pm$}{};

        $name =~ s{^$root/+}{};
        $name =~ s{/}{::}g;

        push @list, $name;

        return 1;
    };

    File::Find::find( { wanted => $process, follow => 1 }, $root );

    return sort @list;
}
