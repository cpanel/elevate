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

use Elevate::Components ();

my @components_from_lib = _get_components_from_lib();

foreach my $component (@components_from_lib) {
    is( $component, in_set(@Elevate::Components::CHECKS), "component '$component' has a check registered in Elevate::Blockers::CHECKS list" );

    my $name = "Elevate::Components::$component";
    my $pkg  = $name->new();
    for my $method ( 'check', 'pre_distro_upgrade', 'post_distro_upgrade' ) {
        my $check_method = $pkg->can($method);
        is( ref $check_method, 'CODE', "$component provides '$method' method" );
    }
}

is(
    [ sort @Elevate::Components::CHECKS ],
    [ sort @components_from_lib ],
    q[all components listed in lib are used by @Elevate::Blockers::CHECKS]
);

done_testing;
exit;

sub _get_components_from_lib {

    my @list;

    opendir( my $dh, $FindBin::Bin . "/../lib/Elevate/Components" ) or die;
    while ( my $e = readdir($dh) ) {
        next unless $e =~ s{\Q.pm\E$}{};
        next if $e eq 'Base';
        push @list, $e;
    }

    return sort @list;
}
