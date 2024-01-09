#!/usr/local/cpanel/3rdparty/bin/perl

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

{
    note "system is up to date.";

    $mock_yum->redefine( _system_update_check => 0 );
    is(
        $yum->_blocker_system_update(),
        {
            id  => q[Elevate::Blockers::Repositories::_blocker_system_update],
            msg => "System is not up to date",
        },
        q{Block if the system is not up to date.}
    );

    $mock_yum->redefine( _system_update_check => 1 );
    is( $yum->_blocker_system_update(), 0, 'System is up to date' );

    $mock_yum->unmock('_system_update_check');
}

my $cpev_mock = Test::MockModule->new('cpev');
my @messages_seen;

my $unvetted            = 'UNVETTED';
my $invalid_syntax      = 'INVALID_SYNTAX';
my $rpms_from_unvetted  = 'USE_RPMS_FROM_UNVETTED_REPO';
my $unused_repo_enabled = 'HAS_UNUSED_REPO_ENABLED';

my $path_yum_repos_d = '/etc/yum.repos.d';

my $mocked_yum_repos_d = Test::MockFile->dir($path_yum_repos_d);

#mkdir $path_yum_repos_d;
is $yum->_check_yum_repos(), undef, "no blockers when directory is empty";

ok scalar Elevate::Blockers::Repositories::VETTED_YUM_REPO(), "VETTED_YUM_REPO populated";

ok( grep( { 'MariaDB103' } Elevate::Blockers::Repositories::VETTED_YUM_REPO() ), 'MariaDB103 is a valid repo' );

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
$mock_json->redefine('Dump' => 'foo');
is $yum->_check_yum_repos() => { $unused_repo_enabled => 1, $unvetted => 1 }, "Using an unknown enabled repo detected";
$cpev_mock->redefine( get_installed_rpms_in_repo => 1 );
is $yum->_check_yum_repos() => { $unvetted => 1, $rpms_from_unvetted => 1 }, "Using an unknown enabled repo with installed packages detected";
is $yum->{_yum_repos_unsupported_with_packages}[0],
    {
        'json_report' => '{"name":"MyRepo","packages":["1"],"path":"/etc/yum.repos.d/Unknown.repo"}',
        'name'        => 'MyRepo'
    }
  ,
  "Names and JSON data of repos are recorded in object";

$cpev_mock->redefine( get_installed_rpms_in_repo => sub { return () } );

$mock_unknown_repo->contents('# whatever');
is $yum->_check_yum_repos(), {}, "no repo set";

$mock_unknown_repo->contents( <<EOS );
[MyRepo]
enabled=0
EOS
is $yum->_check_yum_repos(), {}, "Using an unknown disabled repo";

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

# Now we've tested the caller, let's test the code.
{
    note "Testing _yum_is_stable";
    my $errors = 'something is not right';

    clear_messages_seen();

    my $errors_mock = Test::MockModule->new('Cpanel::SafeRun::Errors');
    $errors_mock->redefine( 'saferunonlyerrors' => sub { return $errors } );

    is( $yum->_yum_is_stable(), 0, "Repositories is not stable and emits STDERR output (but does not exit non-zero)" );
    message_seen( 'ERROR', 'yum appears to be unstable. Please address this before upgrading' );
    message_seen( 'ERROR', 'something is not right' );
    no_messages_seen();
    $errors = '';

    my @mocked;
    push @mocked, Test::MockFile->dir('/var/lib/yum');

    is( $yum->_yum_is_stable(), 0, "/var/lib/yum is missing." );
    message_seen( 'ERROR' => q{Could not read directory '/var/lib/yum': No such file or directory} );

    mkdir '/var/lib/yum';
    push @mocked, Test::MockFile->file( '/var/lib/yum/transaction-all.12345', 'aa' );
    is( $yum->_yum_is_stable(), 0, "There is an outstanding transaction." );
    message_seen( 'ERROR', 'There are unfinished yum transactions remaining. Please address these before upgrading. The tool `yum-complete-transaction` may help you with this task.' );

    unlink '/var/lib/yum/transaction-all.12345';
    is( $yum->_yum_is_stable(), 1, "No outstanding yum transactions are found. we're good to go!" );
}

done_testing();
