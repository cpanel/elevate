#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2026 WebPros International, LLC
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

use Cpanel::Exception ();

use File::Path qw(make_path);
use File::Temp ();

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

my $RPM_QUERY = [ '/usr/bin/rpm', '-q', '--qf', '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}|[%{OBSOLETENAME},]|[%{REQUIRENAME} %{REQUIREFLAGS:depflags} %{REQUIREVERSION},]\n', 'kmod-lve' ];

my $DNF_UPGRADE = [ '/usr/bin/dnf', '-y', '--disableexcludes=main', '--setopt=installonly_limit=0', 'upgrade', 'kmod-lve' ];

my $OLD_BUILD = 'kmod-lve-2.0-43.el8.x86_64|kmod-lve,|kernel-core  ,kmod  ,/bin/sh  ,';
my $NEW_BUILD = 'kmod-lve-2.1-74.el8.x86_64|kmod-lve,|kernel-core  ,kmod >= 2:25-19.el8.cloudlinux.2,/bin/sh  ,';

my $OLD_KERNEL = '4.18.0-305.el8.x86_64';
my $MID_KERNEL = '4.18.0-513.el8.x86_64';
my $NEW_KERNEL = '4.18.0-553.el8.x86_64';

my $OLD_DIR = 'lve-2.0-43.el8';
my $NEW_DIR = 'lve-2.1-74.el8';

my $OLD_MODULE = "/lib/modules/$OLD_KERNEL/extra/$OLD_DIR/kmodlve.ko";
my $NEW_MODULE = "/lib/modules/$NEW_KERNEL/extra/$NEW_DIR/kmodlve.ko";

my %PKG_FILES;

sub reset_pkg_files () {
    %PKG_FILES = (
        'kmod-lve-2.0-43.el8.x86_64' => [ '/etc/depmod.d/kmod-lve.conf', $OLD_MODULE, '/usr/share/doc/kmod-lve/LICENSE' ],
        'kmod-lve-2.0-39.el8.x86_64' => ["/lib/modules/4.18.0-240.el8.x86_64/extra/lve-2.0-39.el8/kmodlve.ko"],
        'kmod-lve-2.1-74.el8.x86_64' => [$NEW_MODULE],
    );
    return;
}

sub rpm_files (@pkgs) { return [ '/usr/bin/rpm', '-ql', @pkgs ] }

# Each rpm query shifts the next response off this list
my @query_responses;
my @cmds;
my $files_query_status = 0;

my $mock_cpev = Test::MockModule->new('cpev');
$mock_cpev->redefine(
    ssystem_hide_and_capture_output => sub ( $, @args ) {
        push @cmds, [@args];

        if ( $args[1] eq '-ql' ) {
            return { status => 1, stdout => [], stderr => ['error: rpmdb open failed'] } if $files_query_status;
            return { status => 0, stderr => [], stdout => [ map { @{ $PKG_FILES{$_} } } @args[ 2 .. $#args ] ] };
        }

        my $resp = shift @query_responses or die "Unexpected rpm query\n";
        return { status => 0, stderr => [], %$resp };
    },
    ssystem_and_die => sub ( $, @args ) {
        push @cmds, [@args];
        return;
    },
);

my $kmod_lve_installed = 1;
my $mock_pkgr          = Test::MockModule->new('Cpanel::Pkgr');
$mock_pkgr->redefine( is_installed => sub ($pkg) { return $pkg eq 'kmod-lve' ? $kmod_lve_installed : 0 } );

my ( $running_kernel, $boot_kernel );
my $reboot_status_error;
my $mock_kernel_status = Test::MockModule->new('Cpanel::Kernel::Status');
$mock_kernel_status->redefine(
    reboot_status => sub () {
        die $reboot_status_error if $reboot_status_error;
        return { running_version => $running_kernel, boot_version => $boot_kernel };
    }
);

my $leapp = cpev->new->leapp;

my $modules_tmp = File::Temp->newdir();
local $Elevate::Leapp::modules_dir = "$modules_tmp";

sub touch ($path) {
    ( my $dir = $path ) =~ s{/[^/]+$}{};
    make_path($dir);
    open( my $fh, '>', $path ) or die "Unable to create $path: $!";
    close $fh;
    return;
}

# The link mirrors the target's path under extra, as weak-modules makes it
sub weak_link ( $kernel, $target, $rel = undef ) {
    $rel //= $target =~ m{/extra/(.+)$} ? $1 : die "No extra path in $target";
    ( my $dir = "$modules_tmp/$kernel/weak-updates/$rel" ) =~ s{/[^/]+$}{};
    make_path($dir);
    symlink( $target, "$modules_tmp/$kernel/weak-updates/$rel" ) or die "Unable to link for $kernel: $!";
    return;
}

sub on_disk ($path) { return $path =~ s{^/lib/modules}{$modules_tmp}r }

# A kernel whose own kmod-lve build is current, a kernel linked to that build,
# and the kernel the superseded build was made for, which is no longer installed
sub reset_modules () {
    File::Path::remove_tree( "$modules_tmp", { keep_root => 1 } );

    touch("$modules_tmp/$NEW_KERNEL/vmlinuz");
    touch( on_disk($NEW_MODULE) );

    touch("$modules_tmp/$MID_KERNEL/vmlinuz");
    weak_link( $MID_KERNEL, $NEW_MODULE );

    touch( on_disk($OLD_MODULE) );

    return;
}

sub reset_state (@responses) {
    @query_responses = @responses;
    @cmds            = ();
    $running_kernel  = $NEW_KERNEL;
    $boot_kernel     = $NEW_KERNEL;
    reset_modules();
    reset_pkg_files();
    return;
}

{
    note 'Skipped on OSes that do not need it';

    my %os_hash = (
        alma   => [ 8, 9 ],
        cent   => [7],
        cloud  => [7],
        ubuntu => [ 20, 22 ],
    );
    foreach my $os ( sort keys %os_hash ) {
        foreach my $version ( @{ $os_hash{$os} } ) {
            set_os_to( $os, $version );
            reset_state();

            is $leapp->remove_leftover_kmod_lve(), undef, "Returns early on $os $version";
            is $leapp->warn_leftover_kmod_lve(),   undef, "Does not warn on $os $version";
            is \@cmds,                             [],    "Nothing is run on $os $version";
            no_messages_seen();
        }
    }
}

set_os_to( 'cloud', 8 );

{
    note 'Nothing to remove';

    $kmod_lve_installed = 0;
    reset_state();
    $leapp->remove_leftover_kmod_lve();
    is \@cmds, [], 'Nothing runs when kmod-lve is not installed';
    $kmod_lve_installed = 1;

    reset_state( { stdout => [$NEW_BUILD] } );
    $leapp->remove_leftover_kmod_lve();
    is \@cmds, [$RPM_QUERY], 'Only the rpm query runs when only current builds are installed';

    reset_state( { stdout => ['kmod-lve-2.0-43.el8.x86_64||kernel-core  ,'] } );
    $leapp->remove_leftover_kmod_lve();
    is \@cmds, [$RPM_QUERY], 'A build that does not obsolete kmod-lve is left alone';

    reset_state( { stdout => [ 'garbage', $NEW_BUILD ] } );
    $leapp->remove_leftover_kmod_lve();
    is \@cmds, [$RPM_QUERY], 'Unexpected rpm output is skipped';
    message_seen( DEBUG => qr/Skipping unexpected rpm output: garbage/ );

    no_messages_seen();
}

{
    note 'Leftover alongside a current build';

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD, 'kmod-lve-2.0-39.el8.x86_64|kmod-lve,|' ] } );
    $leapp->remove_leftover_kmod_lve();
    is(
        \@cmds,
        [
            $RPM_QUERY,
            rpm_files( 'kmod-lve-2.0-43.el8.x86_64', 'kmod-lve-2.0-39.el8.x86_64' ),
            rpm_files('kmod-lve-2.1-74.el8.x86_64'),
            [ '/usr/bin/rpm', '-e', 'kmod-lve-2.0-43.el8.x86_64', 'kmod-lve-2.0-39.el8.x86_64' ],
        ],
        'The leftover builds are removed and the current build is kept',
    );
    message_seen( INFO => qr/Removing superseded kmod-lve packages.*\n\s+kmod-lve-2\.0-43\.el8\.x86_64\n\s+kmod-lve-2\.0-39\.el8\.x86_64$/s );

    reset_state( { stdout => [ 'kmod-lve-2.0-43.el8.x86_64|kmod-lve,|kmod < 3:25-19.el8,', $NEW_BUILD ] } );
    $leapp->remove_leftover_kmod_lve();
    is $cmds[-1], [ '/usr/bin/rpm', '-e', 'kmod-lve-2.0-43.el8.x86_64' ], 'A kmod requirement that is not >= does not make a build current';
    message_seen( INFO => qr/Removing superseded kmod-lve packages/ );

    reset_state( { stdout => [ 'kmod-lve-2.0-43.el8.x86_64|kmod-lve,|kmod >= 1:25-19.el8,', $NEW_BUILD ] } );
    $leapp->remove_leftover_kmod_lve();
    is $cmds[-1], [ '/usr/bin/rpm', '-e', 'kmod-lve-2.0-43.el8.x86_64' ], 'A kmod requirement below epoch 2 does not make a build current';
    message_seen( INFO => qr/Removing superseded kmod-lve packages/ );

    no_messages_seen();
}

{
    note 'Only leftover builds installed';

    reset_state( { stdout => [$OLD_BUILD] }, { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    $leapp->remove_leftover_kmod_lve();
    is(
        \@cmds,
        [
            $RPM_QUERY,
            $DNF_UPGRADE,
            $RPM_QUERY,
            rpm_files('kmod-lve-2.0-43.el8.x86_64'),
            rpm_files('kmod-lve-2.1-74.el8.x86_64'),
            [ '/usr/bin/rpm', '-e', 'kmod-lve-2.0-43.el8.x86_64' ],
        ],
        'The current build is installed before the leftover is removed',
    );
    message_seen( INFO => qr/Installing the current kmod-lve package/ );
    message_seen( INFO => qr/Removing superseded kmod-lve packages/ );

    reset_state(
        { stdout => [ $OLD_BUILD, 'kmod-lve-2.0-39.el8.x86_64|kmod-lve,|' ] },
        { stdout => [ $OLD_BUILD, $NEW_BUILD ] },
    );
    like(
        dies { $leapp->remove_leftover_kmod_lve() },
        qr/unexpectedly removed superseded kmod-lve packages.*:\n    kmod-lve-2\.0-39\.el8\.x86_64\n$/s,
        'Dies if dnf removed a leftover build anyway',
    );
    is( $cmds[-1], $RPM_QUERY, 'Nothing else runs after dnf removed a leftover build' );
    message_seen( INFO => qr/Installing the current kmod-lve package/ );

    reset_state( { stdout => [$OLD_BUILD] }, { stdout => [$NEW_BUILD] } );
    like(
        dies { $leapp->remove_leftover_kmod_lve() },
        qr/unexpectedly removed superseded kmod-lve packages.*:\n    kmod-lve-2\.0-43\.el8\.x86_64\n$/s,
        'Dies rather than returning quietly if dnf removed every leftover build',
    );
    is( $cmds[-1], $RPM_QUERY, 'Nothing else runs after dnf removed every leftover build' );
    message_seen( INFO => qr/Installing the current kmod-lve package/ );

    reset_state( { stdout => [$OLD_BUILD] }, { stdout => [$OLD_BUILD] } );
    like(
        dies { $leapp->remove_leftover_kmod_lve() },
        qr/Unable to install a kmod-lve package that will be replaced during the upgrade/,
        'Dies without removing anything when no current build can be installed',
    );
    ok !( grep { $_->[1] eq '-e' } @cmds ), 'rpm -e is not run';
    message_seen( INFO => qr/Installing the current kmod-lve package/ );

    no_messages_seen();
}

{
    note 'Kernel coverage guard';

    my $K = '4.18.0-372.el8.x86_64';

    # The kernel that relies on the superseded build is the running kernel
    my $blocked = sub ( $desc, $kernel = $K ) {
        $running_kernel = $boot_kernel = $kernel;
        my $err = dies { $leapp->remove_leftover_kmod_lve() };
        like( $err, qr/The running or default boot kernel may load LVE from a superseded kmod-lve package/, "$desc: dies" );
        ok( !( grep { $_->[1] eq '-e' } @cmds ), "$desc: rpm -e is not run" );
        return $err;
    };

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    weak_link( '4.18.0-372.el8.x86_64', $OLD_MODULE );
    touch("$modules_tmp/4.18.0-372.el8.x86_64/vmlinuz");
    my $err = $blocked->('A kernel linked to the superseded build');
    like( $err, qr{\n\s+4\.18\.0-372\.el8\.x86_64 -> \Q$OLD_MODULE\E\n},        'The kernel and the module it loads are named' );
    like( $err, qr/have not been removed:\n\s+kmod-lve-2\.0-43\.el8\.x86_64\n/, 'The packages that were kept are named' );
    unlike( $err, qr/\Q$MID_KERNEL\E|\Q$NEW_KERNEL\E/, 'Kernels using the current build are not named' );

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    touch("$modules_tmp/$OLD_KERNEL/vmlinuz");
    $err = $blocked->( 'The kernel the superseded build was made for is still installed', $OLD_KERNEL );
    like( $err, qr{\n\s+\Q$OLD_KERNEL\E -> \Q$OLD_MODULE\E\n}, 'The kernel with its own superseded module is named' );

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    weak_link( '4.18.0-372.el8.x86_64', "/usr$OLD_MODULE" );
    touch("$modules_tmp/4.18.0-372.el8.x86_64/vmlinuz");
    $blocked->('A weak link through /usr/lib/modules');

    reset_state( { stdout => [$OLD_BUILD] }, { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    weak_link( '4.18.0-372.el8.x86_64', $OLD_MODULE );
    touch("$modules_tmp/4.18.0-372.el8.x86_64/vmlinuz");
    $blocked->('A kernel the newly installed current build does not support');
    message_seen( INFO => qr/Installing the current kmod-lve package/ );

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    touch("$modules_tmp/4.18.0-372.el8.x86_64/vmlinuz");
    weak_link( '4.18.0-425.el8.x86_64', $OLD_MODULE );
    $leapp->remove_leftover_kmod_lve();
    is(
        $cmds[-1], [ '/usr/bin/rpm', '-e', 'kmod-lve-2.0-43.el8.x86_64' ],
        'Kernels without an LVE module, and module trees without an installed kernel, do not block removal'
    );
    message_seen( INFO => qr/Removing superseded kmod-lve packages/ );

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    weak_link( '4.18.0-372.el8.x86_64', "../../../$OLD_KERNEL/./extra/$OLD_DIR/kmodlve.ko", "$OLD_DIR/kmodlve.ko" );
    touch("$modules_tmp/4.18.0-372.el8.x86_64/vmlinuz");
    $err = $blocked->('A relative weak link');
    like( $err, qr{\n\s+4\.18\.0-372\.el8\.x86_64 -> \Q$OLD_MODULE\E\n}, 'The relative link is reported by its resolved path' );

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    $PKG_FILES{'kmod-lve-2.0-43.el8.x86_64'} = ["/usr$OLD_MODULE"];
    weak_link( '4.18.0-372.el8.x86_64', $OLD_MODULE );
    touch("$modules_tmp/4.18.0-372.el8.x86_64/vmlinuz");
    $blocked->('A superseded build that lists its files under /usr/lib/modules');

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    my $OLD_IOLIMITS = "/lib/modules/$OLD_KERNEL/extra/$OLD_DIR/iolimits.ko";
    push @{ $PKG_FILES{'kmod-lve-2.0-43.el8.x86_64'} }, $OLD_IOLIMITS;
    touch("$modules_tmp/$OLD_KERNEL/vmlinuz");
    touch( on_disk($OLD_IOLIMITS) );
    $err = $blocked->( 'A kernel losing more than one module', $OLD_KERNEL );
    like( $err, qr{\Q$OLD_KERNEL\E -> \Q$OLD_IOLIMITS\E\n\s+\Q$OLD_KERNEL\E -> \Q$OLD_MODULE\E\n}, 'Every module the kernel would lose is named' );

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    push @{ $PKG_FILES{'kmod-lve-2.1-74.el8.x86_64'} }, $OLD_MODULE;
    touch("$modules_tmp/$OLD_KERNEL/vmlinuz");
    $leapp->remove_leftover_kmod_lve();
    is( $cmds[-1], [ '/usr/bin/rpm', '-e', 'kmod-lve-2.0-43.el8.x86_64' ], 'A module that a current build also owns does not block removal' );
    message_seen( INFO => qr/Removing superseded kmod-lve packages/ );

    my $allowed = sub ($desc) {
        $leapp->remove_leftover_kmod_lve();
        is( $cmds[-1], [ '/usr/bin/rpm', '-e', 'kmod-lve-2.0-43.el8.x86_64' ], "$desc: the superseded build is removed" );
        message_seen( INFO => qr/Removing superseded kmod-lve packages/ );
        return;
    };

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    my $K_NEW_MODULE = "/lib/modules/$K/extra/$NEW_DIR/kmodlve.ko";
    push @{ $PKG_FILES{'kmod-lve-2.1-74.el8.x86_64'} }, $K_NEW_MODULE;
    touch("$modules_tmp/$K/vmlinuz");
    touch( on_disk($K_NEW_MODULE) );
    weak_link( $K, $OLD_MODULE );
    $allowed->('A kernel with its own current module and a stale link to the superseded build');

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    touch("$modules_tmp/$K/vmlinuz");
    weak_link( $K, $OLD_MODULE );
    weak_link( $K, $NEW_MODULE );
    $allowed->('A kernel linked to both the superseded and the current build');

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    touch("$modules_tmp/$K/vmlinuz");
    weak_link( $K, $OLD_MODULE );
    touch("$modules_tmp/$K/extra/lve-local/kmodlve.ko");
    $err = $blocked->('A module that no package owns does not stand in for the superseded one');
    like( $err, qr{\n\s+\Q$K\E -> \Q$OLD_MODULE\E\n\n}, 'Only the superseded module is named' );
    unlike( $err, qr{lve-local}, 'The unowned module is not named' );

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    touch("$modules_tmp/$K/vmlinuz");
    weak_link( $K, $OLD_MODULE );
    touch("$modules_tmp/$K/updates/kmodlve.ko");
    weak_link( $K, $NEW_MODULE, "$NEW_DIR/kmodlve.ko" );
    $running_kernel = $boot_kernel = $K;
    $allowed->('A current module still covers a kernel that also has an unowned module');

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    touch("$modules_tmp/$K/vmlinuz");
    weak_link( $K, $OLD_MODULE );
    touch("$modules_tmp/$K/extra/lve-local/kmodlve.ko");
    $leapp->remove_leftover_kmod_lve();
    is( $cmds[-1], [ '/usr/bin/rpm', '-e', 'kmod-lve-2.0-43.el8.x86_64' ], 'An unowned module on a kernel that is not booted only warns' );
    message_seen( WARN => qr/ELevate does not boot these kernels.*\n\s+\Q$K\E -> \Q$OLD_MODULE\E$/s );
    message_seen( INFO => qr/Removing superseded kmod-lve packages/ );

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    touch("$modules_tmp/$K/vmlinuz");
    weak_link( $K, "/lib/modules/4.18.0-240.el8.x86_64/extra/lve-2.0-39.el8/kmodlve.ko" );
    $allowed->('A dangling link does not count as a module the kernel loads');

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    touch("$modules_tmp/$K/vmlinuz");
    weak_link( $K, $OLD_MODULE );
    touch("$modules_tmp/$K/extra/$NEW_DIR/iolimits.ko");
    $blocked->('Another module name does not stand in for the one being removed');

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    touch("$modules_tmp/$K/vmlinuz");
    weak_link( '4.18.0-425.el8.x86_64', $OLD_MODULE );
    weak_link( $K, "/lib/modules/4.18.0-425.el8.x86_64/weak-updates/$OLD_DIR/kmodlve.ko", "$OLD_DIR/kmodlve.ko" );
    $err = $blocked->('A link to another link to the superseded build');
    like( $err, qr{\Q$K\E -> \Q$OLD_MODULE\E\n}, 'The chain is reported by the file it ends at' );

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    my $OLD_LVE = "/lib/modules/$OLD_KERNEL/extra/$OLD_DIR/lve.ko";
    $PKG_FILES{'kmod-lve-2.0-43.el8.x86_64'} = [$OLD_LVE];
    touch( on_disk($OLD_LVE) );
    touch("$modules_tmp/$K/vmlinuz");
    weak_link( $K, $OLD_LVE );
    weak_link( $K, $NEW_MODULE );
    $allowed->('A kernel linked to a current build that renamed the module');

    my $old_iolimits = "/lib/modules/$OLD_KERNEL/extra/$OLD_DIR/iolimits.ko";
    my $new_iolimits = "/lib/modules/$NEW_KERNEL/extra/$NEW_DIR/iolimits.ko";

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    push @{ $PKG_FILES{'kmod-lve-2.0-43.el8.x86_64'} }, $old_iolimits;
    push @{ $PKG_FILES{'kmod-lve-2.1-74.el8.x86_64'} }, $new_iolimits;
    touch( on_disk($_) ) for $old_iolimits, $new_iolimits;
    touch("$modules_tmp/$K/vmlinuz");
    weak_link( $K, $NEW_MODULE );
    weak_link( $K, $old_iolimits );
    $err = $blocked->('A current module does not cover another module the current build ships');
    like( $err, qr{\n\s+\Q$K\E -> \Q$old_iolimits\E\n\n}, 'Only the module the kernel would lose is named' );
    unlike( $err, qr{kmodlve}, 'The module the current build covers is not named' );

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    push @{ $PKG_FILES{'kmod-lve-2.0-43.el8.x86_64'} }, $old_iolimits;
    push @{ $PKG_FILES{'kmod-lve-2.1-74.el8.x86_64'} }, $new_iolimits;
    touch( on_disk($_) ) for $old_iolimits, $new_iolimits;
    touch("$modules_tmp/$K/vmlinuz");
    weak_link( $K, $NEW_MODULE );
    weak_link( $K, $new_iolimits );
    weak_link( $K, $old_iolimits, "$OLD_DIR/iolimits.ko" );
    $allowed->('A kernel with current copies of every module the current build ships');

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    push @{ $PKG_FILES{'kmod-lve-2.0-43.el8.x86_64'} }, $old_iolimits;
    touch( on_disk($old_iolimits) );
    touch("$modules_tmp/$K/vmlinuz");
    weak_link( $K, $NEW_MODULE );
    weak_link( $K, $old_iolimits );
    $allowed->('A module that the current build no longer ships does not block a kernel it supports');

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    push @{ $PKG_FILES{'kmod-lve-2.0-43.el8.x86_64'} }, $old_iolimits;
    touch( on_disk($old_iolimits) );
    touch("$modules_tmp/$K/vmlinuz");
    weak_link( $K, $old_iolimits );
    $err = $blocked->('A module that the current build no longer ships blocks a kernel with no current module');
    like( $err, qr{\n\s+\Q$K\E -> \Q$old_iolimits\E\n\n}, 'The dropped module is named' );

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    touch("$modules_tmp/$K/vmlinuz");
    touch("$modules_tmp/$K/kernel/drivers/misc/kmodlve.ko");
    weak_link( $K, $OLD_MODULE );
    $blocked->('A same-named module outside the external module directories');

    note 'Only the running and default boot kernels block';

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    touch("$modules_tmp/$K/vmlinuz");
    weak_link( $K, $OLD_MODULE );
    $leapp->remove_leftover_kmod_lve();
    is( $cmds[-1], [ '/usr/bin/rpm', '-e', 'kmod-lve-2.0-43.el8.x86_64' ], 'A kernel that is neither running nor the default boot kernel does not block removal' );
    message_seen( WARN => qr/ELevate does not boot these kernels.*\n\s+\Q$K\E -> \Q$OLD_MODULE\E$/s );
    message_seen( INFO => qr/Removing superseded kmod-lve packages/ );

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    touch("$modules_tmp/$K/vmlinuz");
    weak_link( $K, $OLD_MODULE );
    $boot_kernel = $K;
    ok( dies { $leapp->remove_leftover_kmod_lve() }, 'The default boot kernel blocks removal when it is not the running kernel' );
    ok( !( grep { $_->[1] eq '-e' } @cmds ),         'rpm -e is not run' );

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    touch("$modules_tmp/$K/vmlinuz");
    touch("$modules_tmp/$OLD_KERNEL/vmlinuz");
    weak_link( $K, $OLD_MODULE );
    $running_kernel = $boot_kernel = $OLD_KERNEL;
    $err            = dies { $leapp->remove_leftover_kmod_lve() };
    like( $err, qr{\n\s+\Q$OLD_KERNEL\E -> \Q$OLD_MODULE\E\n\n}, 'The running kernel is named' );
    unlike( $err, qr/\Q$K\E/, 'Other kernels are not named in the error' );

    note 'The running and boot kernels are always checked';

    # No installed kernel relies on the superseded build in these cases
    my $kept_pkgs = qr/\n\nThe superseded kmod-lve packages have not been removed:\n\s+kmod-lve-2\.0-43\.el8\.x86_64\n$/;

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    $reboot_status_error = "grubby exploded\n";
    like(
        dies { $leapp->remove_leftover_kmod_lve() },
        qr/^Unable to determine the running and boot kernels:\ngrubby exploded$kept_pkgs/,
        'Dies when the running and boot kernels cannot be determined',
    );
    ok( !( grep { $_->[1] eq '-e' } @cmds ), 'rpm -e is not run' );
    is( [ grep { $_->[1] eq '-ql' } @cmds ], [], 'The kernels are determined before the package files are listed' );

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    $reboot_status_error = Cpanel::Exception->create_raw('Cannot determine startup kernel version.');
    like(
        dies { $leapp->remove_leftover_kmod_lve() },
        qr/:\nCannot determine startup kernel version\.$kept_pkgs/,
        'An exception object is reported by its message alone',
    );
    $reboot_status_error = undef;

    foreach my $unknown ( undef, '', '..', '../../etc', '4.18.0 553' ) {
        foreach my $which (qw{ running boot }) {
            my $desc = sprintf( 'A %s kernel of %s', $which, defined $unknown ? "'$unknown'" : 'undef' );

            reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
            ( $which eq 'running' ? $running_kernel : $boot_kernel ) = $unknown;
            like(
                dies { $leapp->remove_leftover_kmod_lve() },
                qr/^Unable to determine the \Q$which\E kernel$kept_pkgs/,
                "$desc blocks removal",
            );
            ok( !( grep { $_->[1] eq '-e' } @cmds ), "$desc: rpm -e is not run" );
        }
    }

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    weak_link( $K, $OLD_MODULE );
    $boot_kernel = $K;
    $err         = dies { $leapp->remove_leftover_kmod_lve() };
    like( $err, qr/The running or default boot kernel may load LVE from a superseded kmod-lve package.*\n\s+\Q$K\E -> \Q$OLD_MODULE\E\n/s, 'A boot kernel without a vmlinuz in its module tree is still checked' );
    ok( !( grep { $_->[1] eq '-e' } @cmds ), 'rpm -e is not run' );

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    weak_link( $K, $OLD_MODULE );
    $running_kernel = $K;
    $err            = dies { $leapp->remove_leftover_kmod_lve() };
    like( $err, qr/The running or default boot kernel may load LVE from a superseded kmod-lve package.*\n\s+\Q$K\E -> \Q$OLD_MODULE\E\n/s, 'A running kernel without a vmlinuz in its module tree is still checked' );
    ok( !( grep { $_->[1] eq '-e' } @cmds ), 'rpm -e is not run' );

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    weak_link( $K, $NEW_MODULE );
    $running_kernel = $boot_kernel = $K;
    $allowed->('A booted kernel without a vmlinuz that the current build covers');

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    $running_kernel = $boot_kernel = '4.18.0-999.el8.x86_64';
    $allowed->('A booted kernel without a module tree has no module to lose');

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    $files_query_status = 1;
    like(
        dies { $leapp->remove_leftover_kmod_lve() },
        qr/Unable to list the files in the kmod-lve packages:\nerror: rpmdb open failed/,
        'Dies when the package files cannot be listed',
    );
    ok( !( grep { $_->[1] eq '-e' } @cmds ), 'rpm -e is not run' );
    $files_query_status = 0;

    no_messages_seen();
}

{
    note 'rpm -e failure';

    $mock_cpev->redefine(
        ssystem_and_die => sub ( $, @args ) {
            push @cmds, [@args];
            die "rpm -e failed: dependencies\n";
        },
    );

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD ] } );
    like(
        dies { $leapp->remove_leftover_kmod_lve() },
        qr/Unable to remove the superseded kmod-lve packages:\n\s+kmod-lve-2\.0-43\.el8\.x86_64\n\nrpm -e failed: dependencies/,
        'The failure names the packages and includes the error',
    );
    message_seen( INFO => qr/Removing superseded kmod-lve packages/ );

    $mock_cpev->redefine(
        ssystem_and_die => sub ( $, @args ) {
            push @cmds, [@args];
            return;
        },
    );

    no_messages_seen();
}

{
    note 'rpm query failure';

    reset_state( { status => 1, stdout => [], stderr => ['error: rpmdb: BDB0113 Thread/process failed'] } );
    like(
        dies { $leapp->remove_leftover_kmod_lve() },
        qr/Unable to query the installed kmod-lve packages:\n.*BDB0113/,
        'Dies when rpm fails for a reason other than kmod-lve not being installed',
    );
    is \@cmds, [$RPM_QUERY], 'Nothing is removed';

    no_messages_seen();
}

{
    note 'Warning for manual upgrades';

    my $steps = qr/-printf '%p -> %l\\n'.*--setopt=installonly_limit=0 upgrade kmod-lve/s;

    reset_state( { stdout => [ $OLD_BUILD, $NEW_BUILD, 'kmod-lve-2.0-39.el8.x86_64|kmod-lve,|' ] } );
    is $leapp->warn_leftover_kmod_lve(), undef,        'Returns undef';
    is \@cmds,                           [$RPM_QUERY], 'Only the rpm query runs';
    message_seen( WARN => qr/superseded kmod-lve packages are installed.*\n\s+kmod-lve-2\.0-43\.el8\.x86_64\n\s+kmod-lve-2\.0-39\.el8\.x86_64\n.*$steps/s );

    reset_state( { stdout => [$OLD_BUILD] } );
    $leapp->warn_leftover_kmod_lve();
    is \@cmds, [$RPM_QUERY], 'Nothing is installed when only superseded builds are installed';
    message_seen( WARN => qr/superseded kmod-lve packages are installed.*\n\s+kmod-lve-2\.0-43\.el8\.x86_64\n.*$steps/s );

    reset_state( { stdout => [$NEW_BUILD] } );
    $leapp->warn_leftover_kmod_lve();
    no_messages_seen();

    $kmod_lve_installed = 0;
    reset_state();
    $leapp->warn_leftover_kmod_lve();
    is \@cmds, [], 'Nothing runs when kmod-lve is not installed';
    $kmod_lve_installed = 1;
    no_messages_seen();

    reset_state( { status => 1, stdout => [], stderr => ['error: rpmdb: BDB0113 Thread/process failed'] } );
    ok( lives { $leapp->warn_leftover_kmod_lve() }, 'A failed rpm query does not die' );
    message_seen( WARN => qr/Unable to check for superseded kmod-lve packages.*\nUnable to query the installed kmod-lve packages:\n.*BDB0113.*$steps/s );

    no_messages_seen();
}

{
    note 'Manual removal steps';

    my $steps = Elevate::Leapp::kmod_lve_removal_steps();
    like( $steps, qr{\Q/lib/modules/*/$_\E\s}, "The find command checks the $_ directories" ) for qw{ updates extra weak-updates };

    my @globs = $steps =~ m{-name '([^']+)'}g;
    ok( scalar @globs, 'The find command matches module names' );
    my $matches = sub ($file) {
        return grep { my $re = quotemeta($_) =~ s{\\\*}{.*}gr; $file =~ m{^$re$} } @globs;
    };
    ok( $matches->($_),  "The find command lists $_" )         for qw{ kmodlve.ko kmodlve.ko.xz iolimits.ko lve.ko };
    ok( !$matches->($_), "The find command does not list $_" ) for qw{ kvdo.ko nvidia.ko };
}

done_testing();
