#!/usr/local/cpanel/3rdparty/bin/perl

# HARNESS-NO-STREAM

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockFile 0.032 qw<nostrict>;
use Test::MockModule     qw/strict/;
use Test::Trap           qw/:output(perlio) :die :exit/;

use FindBin;
use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use Elevate::Components::DiskSpace ();

use cPstrict;

# aliases for testing
use constant MEG => Elevate::Components::DiskSpace::MEG();
use constant GIG => Elevate::Components::DiskSpace::GIG();

my $saferun_output;
my $check;

my $mock_saferun = Test::MockModule->new('Cpanel::SafeRun::Simple');
$mock_saferun->redefine(
    saferunnoerror => sub {
        $saferun_output;
    }
);

for my $securetmp_installed ( 0 .. 1 ) {
    foreach my $os (qw{ cent cloud alma }) {
        set_os_to($os);

        my $mock_diskspace = Test::MockModule->new('Elevate::Components::DiskSpace');
        $mock_diskspace->redefine(
            is_securetmp_installed => $securetmp_installed,
        );

        like(
            dies { check_blocker() },
            qr{Cannot parse df output},
            "_disk_space_check"
        );

        $saferun_output = <<EOS;
Filesystem     1K-blocks     Used Available Use% Mounted on
/dev/vda1       83874796 74579968   9294828  89% /
EOS

        like(
            dies { check_blocker() },
            qr{expected 5 lines ; got 1 lines},
            "_disk_space_check"
        );

        $saferun_output = <<EOS;
Filesystem     1K-blocks     Used Available Use% Mounted on
/dev/vda1       20134592 11245932   8872276  56% /
/dev/vda1       20134592 11245932   8872276  56% /
/dev/loop6        714624       92    677364   1% /tmp
/dev/vda1       20134592 11245932   8872276  56% /
/dev/vda1       20134592 11245932   8872276  56% /
EOS

        is( check_blocker(), 1, "_disk_space_check ok" );

        my $boot = 201 * MEG;

        $saferun_output = <<"EOS";
Filesystem     1K-blocks     Used Available Use% Mounted on
/dev/vda1       20134592 11245932   8872276  56% /
/dev/vda1       20134592 11245932   $boot    56% /
/dev/loop6        714624       92    677364   1% /tmp
/dev/vda1       20134592 11245932   8872276  56% /
/dev/vda1       20134592 11245932   8872276  56% /
EOS

        is( check_blocker(), 1, "_disk_space_check ok - /boot 201 M" );

        $boot = 199 * MEG;

        $saferun_output = <<"EOS";
Filesystem     1K-blocks     Used Available Use% Mounted on
/dev/vda1       20134592 11245932   8872276  56% /
/dev/vda1       20134592 11245932   $boot    56% /
/dev/loop6        714624       92    677364   1% /tmp
/dev/vda1       20134592 11245932   8872276  56% /
/dev/vda1       20134592 11245932   8872276  56% /
EOS

        like(
            warnings { $check = check_blocker() },
            [qr{/boot needs 200 M => available 199 M}],
            q[Got expected warnings]
        );

        is $check, 0, "_disk_space_check failure - /boot 119 M";

        my $usr_local_cpanel = 2 * GIG;

        $saferun_output = <<"EOS";
Filesystem     1K-blocks     Used Available Use% Mounted on
/dev/vda1       20134592 11245932   8872276  56% /
/dev/vda1       20134592 11245932   8872276  56% /
/dev/loop6        714624       92    677364   1% /tmp
/dev/vda1       20134592 11245932   $usr_local_cpanel  56% /
/dev/vda1       20134592 11245932   8872276  56% /
EOS

        is( check_blocker(), 1, "_disk_space_check ok - /usr/local/cpanel 2 G" );

        $usr_local_cpanel = 1.4 * GIG;

        $saferun_output = <<"EOS";
Filesystem     1K-blocks     Used Available Use% Mounted on
/dev/vda1       20134592 11245932   8872276  56% /
/dev/vda1       20134592 11245932   8872276  56% /
/dev/loop6        714624       92    677364   1% /tmp
/dev/vda1       20134592 11245932   $usr_local_cpanel  56% /
/dev/vda1       20134592 11245932   8872276  56% /
EOS

        like(
            warnings { $check = check_blocker() },
            [qr{/usr/local/cpanel needs 1.50 G => available 1.40 G}],
            q[Got expected warnings]
        );

        is $check, 0, "_disk_space_check failure - /usr/local/cpanel 1.4 G";

        {
            note "disk space blocker.";

            my $mock_ds = Test::MockModule->new('Elevate::Components::DiskSpace');
            $mock_ds->redefine( _disk_space_check => 0 );

            my $components = cpev->new()->components;
            is $components->_check_single_blocker('DiskSpace'), 0;

            is(
                $components->blockers,
                [
                    {
                        id  => q[Elevate::Components::DiskSpace::check],
                        msg => "disk space issue",
                    }
                ],
                q{Block if disk space issues.}
            );

            $mock_ds->redefine( _disk_space_check => 1 );
            ok( check_blocker(), 'System is up to date' );
        }

        undef $saferun_output;
        undef $check;
        undef $mock_diskspace;
    }

    set_os_to('ubuntu');

    my $mock_diskspace = Test::MockModule->new('Elevate::Components::DiskSpace');
    $mock_diskspace->redefine(
        is_securetmp_installed => $securetmp_installed,
    );

    $saferun_output = <<EOS;
Filesystem     1K-blocks     Used Available Use% Mounted on
/dev/vda1       20134592 11245932   8872276  56% /
/dev/vda1       20134592 11245932   8872276  56% /
/dev/loop6        726704      316    688604   1% /tmp
/dev/vda1       20134592 11245932   8872276  56% /
/dev/vda1       20134592 11245932   8872276  56% /
EOS

    if ($securetmp_installed) {
        is( check_blocker(), 1, 'Ubuntu _disk_space_check ok (securetmp installed)' );
    }
    else {
        like(
            warnings { $check = check_blocker() },
            [qr{/tmp needs 750 M => available 672 M}],
            q[Got expected warnings],
        );

        is $check, 0, "_disk_space_check failure - /tmp 672 M with securetmp disabled";
    }

    undef $saferun_output;
    undef $check;
    undef $mock_diskspace;
}

{
    note 'test is_securetmp_installed';

    my $components = cpev->new()->components;
    my $ds         = $components->_get_blocker_for('DiskSpace');

    my $fstab = Test::MockFile->file('/etc/fstab');
    $fstab->contents( <<'EOS' );
LABEL=cloudimg-rootfs	/	ext4	discard,errors=remount-ro,usrjquota=quota.user,jqfmt=vfsv1	0	1
LABEL=UEFI	/boot/efi	vfat	umask=0077	0 1
/usr/tmpDSK             /tmp                    ext4    defaults,noauto        0 0

/usr/swpDSK	swap	swap	defaults	0	0
EOS

    is( $ds->is_securetmp_installed(), 1, 'Correctly detects when securetmp is installed' );

    $fstab->contents( <<'EOS' );
LABEL=cloudimg-rootfs	/	ext4	discard,errors=remount-ro,usrjquota=quota.user,jqfmt=vfsv1	0	1
LABEL=UEFI	/boot/efi	vfat	umask=0077	0 1

/usr/swpDSK	swap	swap	defaults	0	0
EOS

    is( $ds->is_securetmp_installed(), 0, 'Correctly detects when securetmp is disabled' );

}

{
    note 'Test pre_distro_upgrade';

    my $components = cpev->new()->components;
    my $ds         = $components->_get_blocker_for('DiskSpace');

    my $orig_read_text = \&File::Slurper::read_text;
    my $mock_slurper   = Test::MockModule->new('File::Slurper');
    $mock_slurper->redefine(
        read_text => sub { die "should not be called\n" },
    );

    foreach my $os (qw{ cent cloud alma }) {
        set_os_to($os);

        ok( lives { $ds->pre_distro_upgrade() }, 'Returns early on systems that do not use do-release-upgrade' );
    }

    set_os_to('ubuntu');

    my $mock_diskspace = Test::MockModule->new('Elevate::Components::DiskSpace');
    $mock_diskspace->redefine(
        is_securetmp_installed             => 0,
        create_disable_securetmp_touchfile => 0,
    );

    ok( lives { $ds->pre_distro_upgrade() }, 'Returns early when securetmp is NOT installed' );

    $mock_diskspace->redefine(
        is_securetmp_installed => 1,
    );

    my $fstab = Test::MockFile->file('/etc/fstab');
    $fstab->contents( <<'EOS' );
LABEL=cloudimg-rootfs	/	ext4	discard,errors=remount-ro,usrjquota=quota.user,jqfmt=vfsv1	0	1
LABEL=UEFI	/boot/efi	vfat	umask=0077	0 1
/usr/tmpDSK             /tmp                    ext4    defaults,noauto        0 0

/usr/swpDSK	swap	swap	defaults	0	0
EOS

    my ( $from, $to );
    my $mock_file_copy = Test::MockModule->new('File::Copy');
    $mock_file_copy->redefine(
        cp => sub {
            ( $from, $to ) = @_;
        },
    );

    my $content;
    $mock_slurper->redefine(
        read_text  => $orig_read_text,
        write_text => sub {
            $content = $_[1];
        },
    );

    ok( lives { $ds->pre_distro_upgrade() }, 'Successfully disables securetmp' );
    is( $from, '/etc/fstab',                'Backs up /etc/fstab' );
    is( $to,   '/etc/fstab.elevate_backup', '/etc/fstab is backed up to the expected location' );
    unlike( $content, qr{/usr/tmpDSK}, 'The securetmp line is removed from /etc/fstab' );
}

{
    note 'Test post_distro_upgrade';

    my $components = cpev->new()->components;
    my $ds         = $components->_get_blocker_for('DiskSpace');

    my $mock_file_copy = Test::MockModule->new('File::Copy');
    $mock_file_copy->redefine(
        mv => sub { die "Do not call this yet\n"; },
    );

    my $mock_fstab_backup_file = Test::MockFile->file( '/etc/fstab.elevate_backup', 'contents go here' );

    foreach my $os (qw{ cent cloud alma }) {
        set_os_to($os);

        ok( lives { $ds->post_distro_upgrade() }, 'Returns early on systems that do not use do-release-upgrade' );
    }

    set_os_to('ubuntu');

    $mock_fstab_backup_file->unlink;

    ok( lives { $ds->post_distro_upgrade() }, 'Returns early when securetmp was not disabled' );

    $mock_fstab_backup_file->contents( <<'EOS' );
LABEL=cloudimg-rootfs	/	ext4	discard,errors=remount-ro,usrjquota=quota.user,jqfmt=vfsv1	0	1
LABEL=UEFI	/boot/efi	vfat	umask=0077	0 1
/usr/tmpDSK             /tmp                    ext4    defaults,noauto        0 0

/usr/swpDSK	swap	swap	defaults	0	0
EOS

    my ( $from, $to );
    $mock_file_copy->redefine(
        mv => sub {
            ( $from, $to ) = @_;
        },
    );

    my $mock_disable_securetmp_dir = Test::MockFile->dir('/var/cpanel/disabled');
    mkdir '/var/cpanel/disabled', 0755;
    my $mock_disable_securetmp_touchfile = Test::MockFile->file( '/var/cpanel/disabled/securetmp', '' );

    my $remove_dir;
    my $remove_opts;
    my $mock_file_path = Test::MockModule->new('File::Path');
    $mock_file_path->redefine(
        remove_tree => sub {
            $remove_dir  = $_[0];
            $remove_opts = $_[1];
        },
    );

    ok( lives { $ds->post_distro_upgrade() }, 'post_distro_upgrade successfully reenables securetmp' );
    is( $from,                                       '/etc/fstab.elevate_backup', 'Moves backup file back into place' );
    is( $to,                                         '/etc/fstab',                'Restores /etc/fstab to its original contents' );
    is( $mock_disable_securetmp_touchfile->exists(), 0,                           'Removes file to disable securetmp' );
    is( $remove_dir,                                 '/tmp',                      'Removes contents of /tmp' );
    is( $remove_opts,                                { keep_root => 1 },          'remove_tree called with expected opts' );
}

{
    note 'Test check_tmp()';

    set_os_to('ubuntu');

    my $components = cpev->new()->components;
    my $ds         = $components->_get_blocker_for('DiskSpace');

    my $mock_diskspace = Test::MockModule->new('Elevate::Components::DiskSpace');
    $mock_diskspace->redefine(
        _disk_space_check => 1,
    );

    my $mock_stages = Test::MockModule->new('Elevate::Stages');
    $mock_stages->redefine(
        get_stage => sub { die "Do not call this\n"; },
    );

    ok( lives { $ds->check_tmp() }, 'Returns if there is enough disk space' );

    $mock_diskspace->redefine(
        _disk_space_check             => 0,
        post_distro_upgrade           => 0,
        _remove_but_dont_stop_service => 0,
    );

    $mock_stages->redefine(
        get_stage => 42,
    );

    my @cmds;
    my $mock_cpev = Test::MockModule->new('cpev');
    $mock_cpev->redefine(
        do_cleanup      => 0,
        ssystem_and_die => sub {
            shift;
            push @cmds, [@_];
        },
    );

    trap { $ds->check_tmp() };
    is( $trap->exit, 69, 'check_tmp() exited with EX_UNAVAILABLE' );

    notification_seen( qr/^Failed to update to/, qr/the script detected that there is not enough disk space/ );

    is(
        \@cmds,
        [
            [
                '/usr/sbin/reboot',
                'now',
            ],
        ],
        'The expected system commands were called'
    );
}

done_testing;
exit;

sub check_blocker (@args) {    # helper for test...

    my $components = cpev->new(@args)->components;
    my $ds         = $components->_get_blocker_for('DiskSpace');

    return $ds->check;
}
