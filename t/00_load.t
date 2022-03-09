#!/usr/local/cpanel/3rdparty/bin/perl

use strict;
use warnings;
use FindBin;

use version;
use Test::More;

open( my $fh, '<', "$FindBin::Bin/cpanfile" ) or die("$!");
while ( my $line = <$fh> ) {
    next unless $line =~ m{requires\s+"([^"]+)"(?:\s+=>\s+"([^"]+)")?;};
    my ( $module, $version ) = ( $1, $2 );

    #next if ($module =~ m/Test2/); # Could lead to unexpected imports.
    require_ok($module);

    next unless length $version;
    ok( eval "version->parse(\$${module}::VERSION)" >= version->parse($version), "$module is at least version $version" );
}

done_testing();
