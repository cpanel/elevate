#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

package test::cpev::blockers;

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

require $FindBin::Bin . '/../elevate-cpanel';

my $blockers = cpev->new->blockers;
my $yum      = $blockers->_get_blocker_for('Repositories');
my $mock_yum = Test::MockModule->new('Elevate::Blockers::Repositories');

my $cpev_mock = Test::MockModule->new('cpev');
my @messages_seen;

my $unvetted            = 'UNVETTED';
my $invalid_syntax      = 'INVALID_SYNTAX';
my $rpms_from_unvetted  = 'USE_RPMS_FROM_UNVETTED_REPO';
my $unused_repo_enabled = 'HAS_UNUSED_REPO_ENABLED';
my $duplicate           = 'DUPLICATE_IDS';

my $path_yum_repos_d = '/etc/yum.repos.d';

my $mocked_yum_repos_d = Test::MockFile->dir($path_yum_repos_d);

#mkdir $path_yum_repos_d;
is $yum->_check_yum_repos(), undef, "no blockers when directory is empty";

for my $os ( 'cent', 'cloud' ) {
    set_os_to($os);

    ok scalar Elevate::OS::vetted_yum_repo(), 'vetted_yum_repo populated';

    ok( grep( { 'MariaDB103' } Elevate::OS::vetted_yum_repo() ), 'MariaDB103 is a valid repo' );
}

my $mock_vetted_repo = Test::MockFile->file( "$path_yum_repos_d/MariaDB103.repo" => q[MariaDB103] );

note "Testing unvetted repo";

mkdir $path_yum_repos_d;

is $yum->_check_yum_repos(), {}, "no blockers when directory is empty";

my $mock_unknown_repo = Test::MockFile->file( "$path_yum_repos_d/Unknown.repo" => <<'EOS' );
[MyRepo]
enabled=1
EOS

$cpev_mock->redefine( get_installed_rpms_in_repo => sub { return () } );

my $mock_json = Test::MockModule->new('Cpanel::JSON');
$mock_json->redefine( 'Dump' => 'foo' );
is $yum->_check_yum_repos() => { $unused_repo_enabled => 1, $unvetted => 1 }, "Using an unknown enabled repo detected";
$cpev_mock->redefine( get_installed_rpms_in_repo => sub { return ('foo'); }, );
is $yum->_check_yum_repos() => { $unvetted => 1, $rpms_from_unvetted => 1 }, "Using an unknown enabled repo with installed packages detected";
is $yum->{_yum_repos_unsupported_with_packages}[0],
  {
    'name' => 'MyRepo',
    'info' => {
        name         => 'MyRepo',
        path         => "$path_yum_repos_d/Unknown.repo",
        num_packages => 1,
        packages     => ['foo'],
    },
  },
  "Names and JSON data of repos are recorded in object";

$cpev_mock->redefine( get_installed_rpms_in_repo => sub { return () } );

$mock_unknown_repo->contents('# whatever');
is $yum->_check_yum_repos(), {}, "no repo set";

$mock_unknown_repo->contents( <<EOS );
[MyRepo]
enabled=0
EOS
is $yum->_check_yum_repos(), { $unvetted => 1 }, "Using an unknown disabled repo";

$mock_unknown_repo->contents( <<EOS );
[MyRepo]
enabled=0

[Another]
enabled=1
EOS

is(
    $yum->_check_yum_repos(), { $unvetted => 1, $unused_repo_enabled => 1 },
    "Using unknown repo with mixed disabled / enabled"
);

note "Testing invalid syntax in repo";

$mock_unknown_repo->unlink;
$mock_vetted_repo->contents( <<'EOS' );
[MariaDB102]
name = MariaDB102
baseurl = http://yum.mariadb.org/10.2/c$releasever-$basearch
enabled=1
EOS

is $yum->_check_yum_repos(), {}, q[vetted repo with valid syntax using $ in url];

$mock_vetted_repo->contents( <<'EOS' );
[MariaDB102]
name = MariaDB102
baseurl = http://yum.mariadb.org/10.2/c\$releasever-$basearch
enabled=1
EOS

is $yum->_check_yum_repos(), { $invalid_syntax => 1 }, q[vetted repo with invalid syntax using a \$ in url];

$mock_vetted_repo->contents( <<'EOS' );
[MariaDB102]
name = MariaDB102
#baseurl = http://yum.mariadb.org/10.2/c\$releasever-$basearch
# this is now fixed just here
baseurl = http://yum.mariadb.org/10.2/c$releasever-$basearch
enabled=1
EOS
is $yum->_check_yum_repos(), {}, q[vetted repo with invalid syntax in a comment is ignored];

$mock_vetted_repo->contents( <<'EOS' );
[MariaDB102]
name = MariaDB102
baseurl = http://yum.mariadb.org/10.2/c$releasever-$basearch # and not \$var
enabled=1
EOS
is $yum->_check_yum_repos(), {}, q[vetted repo with invalid syntax in a comment is ignored];

$mock_vetted_repo->contents( <<'EOS' );
[MariaDB102]
name = MariaDB102
baseurl = http://yum.mariadb.org/10.2/c\$releasever-\$basearch
enabled=1

[MariaDB103]
baseurl = http://yum.mariadb.org/10.3/c$releasever-$basearch
enabled=1
EOS
is $yum->_check_yum_repos(), { $invalid_syntax => 1 }, q[vetted repo with invalid syntax followed by valid syntax -> error];

my $invalid_synax = <<'EOS';
[Unknown]
name = xyz
baseurl = http://get.it/at/\$v1/\$v2
enabled=1
EOS

$mock_vetted_repo->contents(q[whatever]);
$mock_unknown_repo->contents($invalid_synax);

is $yum->_check_yum_repos(), { $unvetted => 1, $unused_repo_enabled => 1 }, "syntax errors in unknown repo are ignored";

my $valid_syn_acks = "[cr]\r\nname=MicroSoft Bob\r\nbaseurl=http://win.doze/gates/\\\$v1/\\\$v2\r\nenabled=1\r\n";
$cpev_mock->redefine( 'get_installed_rpms_in_repo' => sub { return ( 'solitaire.exe', 1 ) } );
$mock_vetted_repo->contents($valid_syn_acks);
$mock_unknown_repo->contents($invalid_synax);
is $yum->_check_yum_repos() => { $unvetted => 1, $rpms_from_unvetted => 1, $invalid_syntax => 1 }, "syntax errors and unvetted repos w/installed RPMs are both reported";

undef $mock_unknown_repo;

my $mock_base_repo = Test::MockFile->file("$path_yum_repos_d/CentOS-Base.repo");
$mock_base_repo->contents( <<'EOS' );
[base]
name=CentOS-$releasever - Base
baseurl=https://vault.centos.org/7.9.2009/os/$basearch
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
EOS

$mock_vetted_repo->contents( <<'EOS' );
[MariaDB102]
name=MariaDB102
baseurl=http://yum.mariadb.org/10.2/c$releasever-$basearch
enabled=1
EOS

is $yum->_check_yum_repos(), {}, q[No duplicate IDs found];

my $mock_duplicate_repo = Test::MockFile->file("$path_yum_repos_d/MariaDB106.repo");
$mock_duplicate_repo->contents( <<'EOS' );
[MariaDB102]
name=MariaDB102
baseurl=http://yum.mariadb.org/10.2/c$releasever-$basearch
enabled=1

[base]
name=CentOS-$releasever - Base
baseurl=https://vault.centos.org/7.9.2009/os/$basearch
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
EOS

is $yum->_check_yum_repos(), { $duplicate => 1, }, q[Duplicate IDs found when a repo with duplicate IDs exists];

is $yum->{_duplicate_repoids}, { 'MariaDB102' => '/etc/yum.repos.d/MariaDB106.repo', 'base' => '/etc/yum.repos.d/MariaDB106.repo' }, q[Expected duplicate IDs found] or diag explain $yum->{_duplicate_repoids};

# Now we've tested the caller, let's test the code.
{
    note "Testing _yum_is_stable";
    my $errors         = 'something is not right';
    my %ssystem_status = (
        '/usr/bin/yum'                                                  => 1,
        Elevate::Blockers::Repositories::YUM_COMPLETE_TRANSACTION_BIN() => 1,
        Elevate::Blockers::Repositories::FIX_RPM_SCRIPT()               => 1,
    );
    my $ssystem_stderr = 'The yum operation has failed';

    clear_messages_seen();

    my $errors_mock = Test::MockModule->new('Cpanel::SafeRun::Errors');
    $errors_mock->redefine( 'saferunonlyerrors' => sub { return $errors } );

    my $run_mock = Test::MockModule->new('Elevate::Roles::Run');
    $run_mock->redefine(
        ssystem_capture_output => sub {
            my $pgm = $_[1];
            note "Trying to run $pgm";
            return {
                status => exists $ssystem_status{$pgm} ? $ssystem_status{$pgm} : 0,
                stderr => $ssystem_stderr,
                stdout => '',
            };
        },
    );

    my $error_msg = <<~'EOS';
    '/usr/bin/yum makecache' failed to return cleanly. This could be due to a temporary mirror problem, or it could indicate a larger issue, such as a broken repository. Since this script relies heavily on yum, you will need to address this issue before upgrading.

    If you need assistance, open a ticket with cPanel Support, as outlined here:

    https://docs.cpanel.net/knowledge-base/technical-support-services/how-to-open-a-technical-support-ticket/
    EOS

    like(
        $yum->_yum_is_stable(),
        {
            id  => q[Elevate::Blockers::Repositories::YumMakeCacheError],
            msg => qr/'\/usr\/bin\/yum makecache' failed to return cleanly/,
        },
        "Repositories is not stable and emits STDERR output (but does not exit non-zero)"
    );
    message_seen( 'WARN',  "Initial run of \"yum makecache\" failed: $errors" );
    message_seen( 'WARN',  "Running \"yum clean all\" in an attempt to fix yum" );
    message_seen( 'WARN',  "Errors encountered running \"yum clean all\": $ssystem_stderr" );
    message_seen( 'ERROR', $error_msg );
    message_seen( 'ERROR', 'something is not right' );
    no_messages_seen();
    $errors = '';

    $mock_yum->redefine( is_check_mode => 1 );

    my @mocked;
    push @mocked, Test::MockFile->dir('/var/lib/yum');

    like(
        $yum->_yum_is_stable(),
        {
            id  => q[Elevate::Blockers::Repositories::YumDirUnreadable],
            msg => qr/Could not read directory/,
        },
        "/var/lib/yum is missing."
    );
    message_seen( 'ERROR' => q{Could not read directory '/var/lib/yum': No such file or directory} );

    mkdir '/var/lib/yum';
    push @mocked, Test::MockFile->file( '/var/lib/yum/transaction-all.12345', 'aa' );
    is( $yum->_yum_is_stable(), 0, "There is an outstanding transaction, check mode." );
    message_seen( 'WARN', 'There are unfinished yum transactions remaining.' );
    message_seen( 'WARN', 'Unfinished yum transactions detected. Elevate will execute /usr/sbin/yum-complete-transaction --cleanup-only during upgrade' );
    no_messages_seen();

    $mock_yum->redefine( is_check_mode => 0 );
    my $mock_yct_bin = Test::MockFile->file( Elevate::Blockers::Repositories::YUM_COMPLETE_TRANSACTION_BIN() );

    like(
        $yum->_yum_is_stable(),
        {
            id  => qr/Elevate::Blockers::Repositories/,
            msg => qr/You must install the yum-utils package/,
        },
        "There is an outstanding transaction, start mode. And yum-complete-transaction is missing."
    );
    message_seen( 'WARN', 'There are unfinished yum transactions remaining.' );
    message_seen( 'WARN', qr/Elevation Blocker detected/ );
    no_messages_seen();

    # Make it exist but not be executable
    $mock_yct_bin->contents('stuff');
    $mock_yct_bin->chmod(0644);

    like(
        $yum->_yum_is_stable(),
        {
            id  => qr/Elevate::Blockers::Repositories/,
            msg => qr/You must install the yum-utils package/,
        },
        "There is an outstanding transaction, start mode. And yum-complete-transaction not executable."
    );
    message_seen( 'WARN', 'There are unfinished yum transactions remaining.' );
    message_seen( 'WARN', qr/Elevation Blocker detected/ );
    no_messages_seen();

    # Make it executable, but  fail when run
    $mock_yct_bin->chmod(0755);

    note explain \%ssystem_status;

    like(
        $yum->_yum_is_stable(),
        {
            id  => qr/Elevate::Blockers::Repositories/,
            msg => "Errors encountered running " . $mock_yct_bin->path() . ": $ssystem_stderr",
        },
        "There is an outstanding transaction, start mode. And yum-complete-transaction fails."
    );
    message_seen( 'WARN', 'There are unfinished yum transactions remaining.' );
    message_seen( 'INFO', 'Cleaning up unfinished yum transactions.' );
    message_seen( 'WARN', qr/Elevation Blocker detected/ );
    no_messages_seen();

    $ssystem_status{ Elevate::Blockers::Repositories::YUM_COMPLETE_TRANSACTION_BIN() } = 0;

    like(
        $yum->_yum_is_stable(),
        {
            id  => qr/Elevate::Blockers::Repositories/,
            msg => "Errors encountered running " . Elevate::Blockers::Repositories::FIX_RPM_SCRIPT() . ": $ssystem_stderr",
        },
        "There is an outstanding transaction, start mode. And the fix rpm script failed"
    );
    message_seen( 'WARN', 'There are unfinished yum transactions remaining.' );
    message_seen( 'INFO', 'Cleaning up unfinished yum transactions.' );
    message_seen( 'WARN', qr/Elevation Blocker detected/ );
    no_messages_seen();

    $ssystem_status{ Elevate::Blockers::Repositories::FIX_RPM_SCRIPT() } = 0;

    is( $yum->_yum_is_stable(), 0, "There is an outstanding transaction, start mode. And nothing fails." );
    message_seen( 'WARN', 'There are unfinished yum transactions remaining.' );
    message_seen( 'INFO', 'Cleaning up unfinished yum transactions.' );
    no_messages_seen();

    unlink '/var/lib/yum/transaction-all.12345';
    is( $yum->_yum_is_stable(), 0, "No outstanding yum transactions are found. we're good to go!" );
    no_messages_seen();
}

{
    note 'Testing pacakges installed without associated repos blocker';

    my $stdout = <<'EOS';
Loaded plugins: fastestmirror, universal-hooks
Loading mirror speeds from cached hostfile
 * cpanel-addons-production-feed: 184.94.196.92
 * epel: mirror.compevo.com
Extra Packages
build.noarch                                      20161128-233.1.234.cpanel
                                                                       @cp-dev-tools
build-mkbaselibs.noarch                           20161128-233.1.234.cpanel
                                                                       @cp-dev-tools
cp-dev-tools-release.noarch                       1-3.3.cpanel         installed
cpanel-3rdparty-bin.noarch                        108.1-1.cp108~el7    installed
cpanel-ace-editor.noarch                          1.3.1-1.cp108~el7    installed
cpanel-analog.x86_64                              6.0-1.cp108~el7      installed
cpanel-angular-chosen.noarch                      1.4.0-1.cp108~el7    installed
cpanel-angular-growl-2.noarch                     0.7.3-1.cp108~el7    installed
cpanel-angular-minicolors.noarch                  0.0.11-1.cp108~el7   installed
cpanel-angular-ui-bootstrap.noarch                1.2.5-1.cp108~el7    installed
cpanel-angular-ui-bootstrap-devel.noarch          1.2.5-1.cp108~el7    installed
cpanel-angular-ui-scroll.noarch                   1.6.1-1.cp108~el7    installed
cpanel-angularjs.noarch                           1.4.4-1.cp108~el7    installed
cpanel-awstats.noarch                             7.8-1.cp108~el7      installed
cpanel-banners-plugin.noarch                      1.0.0-9.16.2.cpanel  installed
cpanel-bindp.x86_64                               1.0.0-1.cp108~el7    installed
cpanel-boost.x86_64                               1.80-1.cp110~el7     installed
cpanel-boost-program-options.x86_64               1.80-1.cp110~el7     installed
cpanel-bootstrap.noarch                           3.1.1-2.cp108~el7    installed
cpanel-bootstrap-devel.noarch                     3.1.1-2.cp108~el7    installed
cpanel-bootstrap-rtl.noarch                       0.9.16-1.cp108~el7   installed
cpanel-bootstrap-rtl-devel.noarch                 0.9.16-1.cp108~el7   installed
cpanel-bootstrap5.noarch                          5.1.3-1.cp108~el7    installed
EOS

    my @stdout_lines = split "\n", $stdout;

    my $run_mock = Test::MockModule->new('Elevate::Roles::Run');
    $run_mock->redefine(
        ssystem_hide_and_capture_output => sub {
            my $pgm = $_[1];
            note "Trying to run $pgm";
            return {
                status => 0,
                stdout => \@stdout_lines,
            };
        },
    );

    like(
        $yum->_blocker_packages_installed_without_associated_repo(),
        {
            id  => 'Elevate::Blockers::Repositories::_blocker_packages_installed_without_associated_repo',
            msg => qr/There are packages installed that do not have associated repositories/,
        },
        'Packages installed without an associated repo',
    );

    message_seen( 'WARN', qr/There are packages installed that do not have associated repositories/ );

    @stdout_lines = ();

    is(
        $yum->_blocker_packages_installed_without_associated_repo(),
        undef,
        'No packages installed without an associated repo',
    );

    no_messages_seen();
}

done_testing();
