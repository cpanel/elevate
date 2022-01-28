#!/usr/local/cpanel/3rdparty/bin/perl

# cpanel - t/blockers_check_yum_repos.t            Copyright 2022 cPanel, L.L.C.
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockFile qw/strict/;
use Test::MockModule qw/strict/;

use cPstrict;
require $FindBin::Bin . '/../elevate-cpanel';

my $cpev_mock = Test::MockModule->new('cpev');
my @messages_seen;
$cpev_mock->redefine(
    _msg => sub ( $level, $msg ) {
        note "mocked output $level", $msg;
    }
);

my $mask_unvetted       = cpev::_CHECK_YUM_REPO_BITMASK_UNVETTED();
my $mask_invalid_syntax = cpev::_CHECK_YUM_REPO_BITMASK_INVALID_SYNTAX();
my $mask_all_issues     = $mask_unvetted | $mask_invalid_syntax;

my $path_yum_repos_d = '/etc/yum.repos.d';

my $mocked_yum_repos_d = Test::MockFile->dir($path_yum_repos_d);

is cpev::_check_yum_repos(), undef, "no blockers when directory is empty";

ok scalar cpev::VETTED_YUM_REPO(), "VETTED_YUM_REPO populated";

foreach my $repo ( cpev::VETTED_YUM_REPO() ) {
    fail("$repo is not a valid repo name") unless $repo =~ qr{\.repo$};
}

ok( grep( { 'MariaDB103.repo' } cpev::VETTED_YUM_REPO() ), 'MariaDB103.repo is a valid repo' );

my $mock_vetted_repo = Test::MockFile->file( "$path_yum_repos_d/MariaDB103.repo" => q[Whatever] );

note "Testing unvetted repo";

is cpev::_check_yum_repos(), 0, "no blockers when directory is empty";

my $mock_unknown_repo = Test::MockFile->file( "$path_yum_repos_d/Unknown.repo" => <<'EOS' );
[MyRepo]
enabled=1
EOS

is cpev::_check_yum_repos() => $mask_unvetted, "Using an unknown enabled repo detected";

$mock_unknown_repo->contents('# whatever');
ok !cpev::_check_yum_repos(), "no repo set";

$mock_unknown_repo->contents( <<EOS );
[MyRepo]
enabled=0
EOS
ok !cpev::_check_yum_repos(), "Using an unknown disabled repo";

$mock_unknown_repo->contents( <<EOS );
[MyRepo]
enabled=0

[Another]
enabled=1
EOS
is cpev::_check_yum_repos() => $mask_unvetted, "Using unknown repo with mixed disabled / enabled";

note "Testing invalid syntax in repo";

$mock_unknown_repo->unlink;
$mock_vetted_repo->contents( <<'EOS' );
[OhMaria]
name = MariaDB102
baseurl = http://yum.mariadb.org/10.2/c$releasever-$basearch
enabled=1
EOS

ok !cpev::_check_yum_repos(), q[vetted repo with valid syntax using $ in url];

$mock_vetted_repo->contents( <<'EOS' );
[OhMaria]
name = MariaDB102
baseurl = http://yum.mariadb.org/10.2/c\$releasever-$basearch
enabled=1
EOS

# {
#     use File::Slurper qw/read_text/;
#     note read_text( $mock_vetted_repo->path );
# }

is cpev::_check_yum_repos() => $mask_invalid_syntax, q[vetted repo with invalid syntax using a \$ in url];

$mock_vetted_repo->contents( <<'EOS' );
[OhMaria]
name = MariaDB102
#baseurl = http://yum.mariadb.org/10.2/c\$releasever-$basearch
# this is now fixed just here
baseurl = http://yum.mariadb.org/10.2/c$releasever-$basearch
enabled=1
EOS
is cpev::_check_yum_repos() => 0, q[vetted repo with invalid syntax in a comment is ignored];

$mock_vetted_repo->contents( <<'EOS' );
[OhMaria]
name = MariaDB102
baseurl = http://yum.mariadb.org/10.2/c$releasever-$basearch # and not \$var
enabled=1
EOS
is cpev::_check_yum_repos() => 0, q[vetted repo with invalid syntax in a comment is ignored];

$mock_vetted_repo->contents( <<'EOS' );
[OhMaria]
name = MariaDB102
baseurl = http://yum.mariadb.org/10.2/c\$releasever-\$basearch
enabled=1

[Fixed]
baseurl = http://yum.mariadb.org/10.2/c$releasever-$basearch
enabled=1
EOS
is cpev::_check_yum_repos() => $mask_invalid_syntax, q[vetted repo with invalid syntax followed by valid syntax -> error];

my $invalid_synax = <<'EOS';
[Unknown]
name = xyz
baseurl = http://get.it/at/\$v1/\$v2
enabled=1
EOS

$mock_vetted_repo->contents(q[whatever]);
$mock_unknown_repo->contents($invalid_synax);

is cpev::_check_yum_repos() => $mask_unvetted, "syntax errors in unknown repo are ignored";

$mock_vetted_repo->contents($invalid_synax);
$mock_unknown_repo->contents($invalid_synax);
is cpev::_check_yum_repos() => $mask_all_issues, "syntax errors and unvetted repos are both reported";

done_testing;
