#!/usr/local/cpanel/3rdparty/bin/perl

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockFile 0.025 qw/strict/;
use Test::MockModule qw/strict/;

use cPstrict;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

my $cpev_mock = Test::MockModule->new('cpev');
my @messages_seen;
$cpev_mock->redefine(
    get_installed_rpms_in_repo => 0,    # for now
);

my $unvetted            = 'UNVETTED';
my $invalid_syntax      = 'INVALID_SYNTAX';
my $rpms_from_unvetted  = 'USE_RPMS_FROM_UNVETTED_REPO';
my $unused_repo_enabled = 'HAS_UNUSED_REPO_ENABLED';

my $path_yum_repos_d = '/etc/yum.repos.d';

my $mocked_yum_repos_d = Test::MockFile->dir($path_yum_repos_d);

my $cpev = bless {}, 'cpev';

is $cpev->_check_yum_repos(), undef, "no blockers when directory is empty";

ok scalar cpev::VETTED_YUM_REPO(), "VETTED_YUM_REPO populated";

ok( grep( { 'MariaDB103' } cpev::VETTED_YUM_REPO() ), 'MariaDB103 is a valid repo' );

my $mock_vetted_repo = Test::MockFile->file( "$path_yum_repos_d/MariaDB103.repo" => q[MariaDB103] );

note "Testing unvetted repo";

mkdir $path_yum_repos_d;

is $cpev->_check_yum_repos(), {}, "no blockers when directory is empty";

my $mock_unknown_repo = Test::MockFile->file( "$path_yum_repos_d/Unknown.repo" => <<'EOS' );
[MyRepo]
enabled=1
EOS

is $cpev->_check_yum_repos() => {$unused_repo_enabled => 1, $unvetted => 1}, "Using an unknown enabled repo detected";

$cpev_mock->redefine( get_installed_rpms_in_repo => 1 );
is $cpev->_check_yum_repos() => {$unvetted => 1, $rpms_from_unvetted => 1}, "Using an unknown enabled repo with installed packages detected";
is $cpev->{_yum_repos_unsupported_with_packages}, ['MyRepo'], "Names of repos are recorded in object";

$cpev_mock->redefine( get_installed_rpms_in_repo => 0 );

$mock_unknown_repo->contents('# whatever');
is $cpev->_check_yum_repos(), {}, "no repo set";

$mock_unknown_repo->contents( <<EOS );
[MyRepo]
enabled=0
EOS
is $cpev->_check_yum_repos(), {}, "Using an unknown disabled repo";

$mock_unknown_repo->contents( <<EOS );
[MyRepo]
enabled=0

[Another]
enabled=1
EOS
is $cpev->_check_yum_repos(), { $unvetted => 1, $unused_repo_enabled => 1}, "Using unknown repo with mixed disabled / enabled";

note "Testing invalid syntax in repo";

$mock_unknown_repo->unlink;
$mock_vetted_repo->contents( <<'EOS' );
[MariaDB102]
name = MariaDB102
baseurl = http://yum.mariadb.org/10.2/c$releasever-$basearch
enabled=1
EOS

is $cpev->_check_yum_repos(), {}, q[vetted repo with valid syntax using $ in url];

$mock_vetted_repo->contents( <<'EOS' );
[MariaDB102]
name = MariaDB102
baseurl = http://yum.mariadb.org/10.2/c\$releasever-$basearch
enabled=1
EOS

is $cpev->_check_yum_repos(), {$invalid_syntax => 1}, q[vetted repo with invalid syntax using a \$ in url];

$mock_vetted_repo->contents( <<'EOS' );
[MariaDB102]
name = MariaDB102
#baseurl = http://yum.mariadb.org/10.2/c\$releasever-$basearch
# this is now fixed just here
baseurl = http://yum.mariadb.org/10.2/c$releasever-$basearch
enabled=1
EOS
is $cpev->_check_yum_repos(), {}, q[vetted repo with invalid syntax in a comment is ignored];

$mock_vetted_repo->contents( <<'EOS' );
[MariaDB102]
name = MariaDB102
baseurl = http://yum.mariadb.org/10.2/c$releasever-$basearch # and not \$var
enabled=1
EOS
is $cpev->_check_yum_repos(), {}, q[vetted repo with invalid syntax in a comment is ignored];

$mock_vetted_repo->contents( <<'EOS' );
[MariaDB102]
name = MariaDB102
baseurl = http://yum.mariadb.org/10.2/c\$releasever-\$basearch
enabled=1

[MariaDB103]
baseurl = http://yum.mariadb.org/10.3/c$releasever-$basearch
enabled=1
EOS
is $cpev->_check_yum_repos(), {$invalid_syntax => 1}, q[vetted repo with invalid syntax followed by valid syntax -> error];

my $invalid_synax = <<'EOS';
[Unknown]
name = xyz
baseurl = http://get.it/at/\$v1/\$v2
enabled=1
EOS

$mock_vetted_repo->contents(q[whatever]);
$mock_unknown_repo->contents($invalid_synax);

is $cpev->_check_yum_repos(), { $unvetted => 1, $unused_repo_enabled => 1 }, "syntax errors in unknown repo are ignored";

my $valid_syn_acks = "[cr]\r\nname=MicroSoft Bob\r\nbaseurl=http://win.doze/gates/\\\$v1/\\\$v2\r\nenabled=1\r\n";
$cpev_mock->redefine('get_installed_rpms_in_repo' => sub { return ( 'solitaire.exe', 1 ) } );
$mock_vetted_repo->contents($valid_syn_acks);
$mock_unknown_repo->contents($invalid_synax);
is $cpev->_check_yum_repos() => { $unvetted => 1, $rpms_from_unvetted => 1, $invalid_syntax => 1 }, "syntax errors and unvetted repos w/installed RPMs are both reported";

done_testing;
