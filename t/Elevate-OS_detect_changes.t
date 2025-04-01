#!/usr/local/cpanel/3rdparty/bin/perl -w

# cpanel - t/Elevate-OS_detect_changes.t           Copyright 2025 cPanel, L.L.C.
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

use cPstrict;

use FindBin;

use Test2::V0;

use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use lib $FindBin::Bin . "/../lib";
use Elevate::OS ();

use lib $FindBin::Bin . "/lib";
use Test::Elevate::OS ();
my $OS_DUMP_DIR = $FindBin::Bin . q[/os.dump];

use constant LOCK_FILE => '/tmp/.t-elevate-os-detect-changes.lock';

use Fcntl qw(:flock);

use File::Slurper qw{ read_text write_text };

use Term::Table ();
use Data::Dump  qw(dump pp);

use constant TABLE_WIDTH => 300;
$Data::Dump::LINEWIDTH = $Data::Dump::LINEWIDTH = 60;

# this tests can be triggered from several symlinks, but the logic is the same
#   we just need to run it once.
my $lock = acquire_lock_or_skip_all();

my $dump_dir = $OS_DUMP_DIR;

my %rows_per_method;
my @headers = qw{ key distro major };

my $ix = -1;
foreach my $os ( Elevate::OS::SUPPORTED_DISTROS() ) {
    ++$ix;

    my ( $distro, $major ) = split ' ', $os;

    my $as_distro = lc "set_os_to_${distro}_${major}";
    note $as_distro;
    my $mock_os = Test::Elevate::OS->can($as_distro)->();

    foreach my $method ( Elevate::OS::supported_methods() ) {

        $rows_per_method{$method} //= [];

        $rows_per_method{$method}->[$ix] //= [ $method, $distro, $major ];

        my $data = Elevate::OS::instance->$method();
        $data = [ sort $data->@* ] if ref $data eq 'ARRAY';
        push $rows_per_method{$method}->[$ix]->@*, pp($data);    # PPI NO PARSE -- false positive it s coming from Elevate::OS

    }

}

my $content = header();

foreach my $method ( Elevate::OS::supported_methods() ) {
    my $table = Term::Table->new( header => [ @headers, $method ], rows => $rows_per_method{$method}, max_width => TABLE_WIDTH );

    $content .= <<"EOS";

## $method

---
EOS

    $content .= q[```] . qq[\n];
    $content .= "$_\n" foreach $table->render;
    $content .= q[```] . qq[\n];
    $content .= "---\n\n";

}

my $dump_file = $OS_DUMP_DIR . '/elevate-os-dump.md';

my $ok;
if ( -e $dump_file ) {
    my $previous_content = read_text($dump_file);
    is( $content, $previous_content, "os.d dump is up to date" ) and $ok = 1;
}
else {
    fail "$dump_file is not versioned, add it to the git repo";
}

if ( !$ok ) {
    note qq[updating $dump_file];
    write_text( $dump_file => $content );
    diag <<EOS;
# ==============================================================================
This test fails when changes to Elevate::OS are made and result in new behavior.
In this case, run this test and commit the files in 't/os.dump' as part
of your changes.

Doing so allows you or any person reviewing the code to spot the behavior change
as a result of your commit.
# ==============================================================================
EOS

}

done_testing;

sub acquire_lock_or_skip_all {

    # acquire a lock once

    open( my $fh, '>', LOCK_FILE ) or die;

    if ( flock( $fh, LOCK_EX | LOCK_NB ) ) {
        print {$fh} "$$\n";
        note q[Lock Acquired];
        return $fh;
    }

    skip_all("Only run a single instance of Elevate-OS_detect_changes.t");

    return;
}

sub header {
    return <<'EOS';
# Elevate::OS - os.dump

## Why this file?

This file provides a rendering of all supported Elevate::OS values.

The goal is to provide a comprehensive view of the impact of a change for each commit.

Some values are defined in `virtual` classes. Changing a boolean value for example could impact more distros than expected.

This file provides the **developer** and the **reviewer** with the ability to better **understand** the *scope* of a **Elevate::OS change**.

## When do I update this file?

Each commit introducing changes to Elevate::OS should update this file. Automated tools exist to detect and update it automatically.

When adding a new file to Elevate::OS namespace or altering the existing ones with:
 - new values
 - removed values
 - altered values

## How do I update this file?

By running the unit test `t/Elevate-OS_detect_changes.t`, this file will be updated automatically. The test will fail if changes are detected. This allows cplint and smokers to block merges when this file needs updating.

```
yath -v t/Elevate-OS_detect_changes.t
```

# A dump of all keys:

EOS
}

1;
