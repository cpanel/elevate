#!/usr/local/cpanel/3rdparty/bin/perl

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use cPstrict;

use lib $FindBin::Bin . "/lib", $FindBin::Bin . "/../lib";

use Elevate::Blockers ();

my @blockers_from_lib = _get_blockers_from_lib();

foreach my $blocker (@blockers_from_lib) {
    is( $blocker, in_set(@Elevate::Blockers::BLOCKERS), "blocker '$blocker' is listed by Elevate::Blockers::BLOCKERS list" );
}

is(
    [ sort @Elevate::Blockers::BLOCKERS ],
    [ sort @blockers_from_lib ],
    q[all blockers listed in lib are used by @Elevate::Blockers::BLOCKERS]
);

done_testing;
exit;

sub _get_blockers_from_lib {

    my @list;

    opendir( my $dh, $FindBin::Bin . "/../lib/Elevate/Blockers" ) or die;
    while ( my $e = readdir($dh) ) {
        next unless $e =~ s{\Q.pm\E$}{};
        next if $e eq 'Base';
        push @list, $e;
    }

    return sort @list;
}
