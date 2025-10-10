#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

package test::cpev::components;

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockFile 0.032;
use Test::MockModule qw/strict/;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;

my $unconvertedmodules      = cpev->new->get_component('UnconvertedModules');
my $mock_unconvertedmodules = Test::MockModule->new('Elevate::Components::UnconvertedModules');

my %os_hash = (
    alma => [8],
    cent => [7],
);

$mock_unconvertedmodules->redefine(
    _remove_leapp_packages_from_yum_excludes => 1,
);

my $mock_pkgmgr = Test::MockModule->new('Elevate::PkgMgr');
$mock_pkgmgr->redefine(
    get_leapp_pkgs => sub {
        return qw{
          elevate-release
          snactor
          leapp
          leapp-data-almalinux
          leapp-data-cloudlinux
          leapp-deps
          leapp-repository-deps
          leapp-upgrade
          python2-leapp
          python3-leapp
        };
    },
);

{
    note "checking _remove_leapp_packages";

    foreach my $distro ( keys %os_hash ) {
        foreach my $version ( @{ $os_hash{$distro} } ) {
            set_os_to( $distro, $version );

            my $mock_cpanel_pkgr = Test::MockModule->new('Cpanel::Pkgr');
            $mock_cpanel_pkgr->redefine(
                is_installed => sub ($pkg) {
                    return ( $pkg eq 'elevate-release' || $pkg eq 'leapp-data-almalinux' ) ? 1 : 0;
                }
            );

            my @cmds;
            my $system_status;
            my $pkgmgr_mock = Test::MockModule->new( ref Elevate::PkgMgr::instance() );
            $pkgmgr_mock->redefine(
                ssystem_and_die => sub ( $, @args ) {
                    push @cmds, [@args];
                    return $system_status;
                },
                _pkgmgr => '/usr/bin/dnf',
            );

            $unconvertedmodules->_remove_leapp_packages();
            is(
                \@cmds,
                [
                    [
                        '/usr/bin/dnf',
                        '-y',
                        'remove',
                        'elevate-release',
                        'leapp-data-almalinux',
                    ],
                ],
                'The expected leapp packages are removed',
            );

            message_seen( 'INFO', 'Removing packages provided by leapp' );
            no_messages_seen();
        }
    }
}

{
    note "checking _warn_about_other_modules_that_did_not_convert";

    foreach my $distro ( keys %os_hash ) {
        foreach my $version ( @{ $os_hash{$distro} } ) {
            set_os_to( $distro, $version );

            my $mock_packages = {};
            my $mock_rpm      = Test::MockModule->new( ref Elevate::PkgMgr::instance() );
            $mock_rpm->redefine(
                get_installed_pkgs => sub {
                    return $mock_packages;
                },
            );

            $unconvertedmodules->_warn_about_other_modules_that_did_not_convert();
            no_messages_seen();

            my $message;
            my $mock_notify = Test::MockModule->new('Elevate::Notify');
            $mock_notify->redefine(
                add_final_notification => sub {
                    ($message) = @_;
                },
            );

            $mock_packages = {
                'foo'                   => 1,
                'bar'                   => 1,
                'finn'                  => '1.el7.x86_64',
                'quinn'                 => '2.el8.x86_64',
                'acronis-backup-cpanel' => 1,
                'kernel'                => '3.10.el7.x86_64',
                'kernel-tools'          => '3.10.el7.x86_64',
            };
            $unconvertedmodules->_warn_about_other_modules_that_did_not_convert();

            my $expected_os_pretty_name = Elevate::OS::upgrade_to_pretty_name();
            my $expected_pkg            = $distro eq 'cent' ? 'finn-1.el7.x86_64' : 'quinn-2.el8.x86_64';
            is(
                $message,
                <<"EOS",
The following packages should probably be removed as they will not function on $expected_os_pretty_name

    $expected_pkg

You can remove these by running: yum -y remove $expected_pkg
EOS
                'The expected final notification is added'
            );

            no_messages_seen();
        }
    }
}

{
    note 'Testing _remove_leapp_packages_from_yum_excludes';

    $mock_unconvertedmodules->unmock('_remove_leapp_packages_from_yum_excludes');

    set_os_to_almalinux_9();

    my ( $read, $write, $file );
    my $mock_file_slurper = Test::MockModule->new('File::Slurper');
    $mock_file_slurper->redefine(
        read_text  => sub { die "similate failure\n"; },
        write_text => sub { die "yikes\n"; },
    );

    try_ok { $unconvertedmodules->_remove_leapp_packages_from_yum_excludes() } 'Lives ok';

    $mock_file_slurper->redefine(
        read_text  => sub { return $read; },
        write_text => sub { ( $file, $write ) = @_; },
    );

    $read = _get_yum_conf();

    try_ok { $unconvertedmodules->_remove_leapp_packages_from_yum_excludes() } 'Lives ok';
    is( $file,  '/etc/yum.conf', 'Expected file written to' );
    is( $write, $read,           'Nothing changed when exclude line is missing' );

    undef $write;
    undef $file;

    $read = _get_yum_conf();
    $read .= "exclude=bind-chroot dovecot* exim* filesystem nsd* p0f php* proftpd* pure-ftpd*\n";

    try_ok { $unconvertedmodules->_remove_leapp_packages_from_yum_excludes() } 'Lives ok';
    is( $file,  '/etc/yum.conf', 'Expected file written to' );
    is( $write, $read,           'Nothing changed when nothing needs altered in the exclude line' );

    undef $write;
    undef $file;

    $read = _get_yum_conf();
    $read .= "exclude=bind-chroot dovecot* exim* leapp,leapp-data-almalinux filesystem snactor nsd* p0f php* proftpd* pure-ftpd* elevate-release\n";

    my $expect = _get_yum_conf();
    $expect .= "exclude=bind-chroot dovecot* exim* filesystem nsd* p0f php* proftpd* pure-ftpd*\n";

    try_ok { $unconvertedmodules->_remove_leapp_packages_from_yum_excludes() } 'Lives ok';
    is( $file,  '/etc/yum.conf', 'Expected file written to' );
    is( $write, $expect,         'Nothing changed when nothing needs altered in the exclude line' );
}

sub _get_yum_conf {
    my $txt = <<'EOF';
[main]
tolerant=1
plugins=1
gpgcheck=1
installonly_limit=3
clean_requirements_on_remove=True
best=True
skip_if_unavailable=False
minrate=50k
ip_resolve=4
EOF

    return $txt;
}

done_testing();
