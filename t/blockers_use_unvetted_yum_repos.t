#!/usr/local/cpanel/3rdparty/bin/perl

# cpanel - t/blockers_use_unvetted_yum_repos.t     Copyright 2022 cPanel, L.L.C.
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

my $path_yum_repos_d = '/etc/yum.repos.d';

my $mocked_yum_repos_d = Test::MockFile->dir($path_yum_repos_d);

is cpev::_use_unvetted_yum_repos(), undef, "no blockers when directory is empty";

ok scalar cpev::VETTED_YUM_REPO(), "VETTED_YUM_REPO populated";

foreach my $repo ( cpev::VETTED_YUM_REPO() ) {
    fail("$repo is not a valid repo name") unless $repo =~ qr{\.repo$};
}

ok( grep( { 'MariaDB103.repo' } cpev::VETTED_YUM_REPO() ), 'MariaDB103.repo is a valid repo' );

my $mock_repo_mariadb103 = Test::MockFile->file( "$path_yum_repos_d/MariaDB103.repo" => q[Whatever] );

is cpev::_use_unvetted_yum_repos(), undef, "no blockers when directory is empty";

my $mock_unknown_repo = Test::MockFile->file( "$path_yum_repos_d/Unknown.repo" => <<'EOS' );
[MyRepo]
enabled=1
EOS

ok cpev::_use_unvetted_yum_repos(), "Using an unknown enabled repo detected";

$mock_unknown_repo->contents('# whatever');
ok !cpev::_use_unvetted_yum_repos(), "no repo set";

$mock_unknown_repo->contents( <<EOS );
[MyRepo]
enabled=0
EOS
ok !cpev::_use_unvetted_yum_repos(), "Using an unknown disabled repo";

$mock_unknown_repo->contents( <<EOS );
[MyRepo]
enabled=0

[Another]
enabled=1
EOS
ok cpev::_use_unvetted_yum_repos(), "Using unknown repo with mixed disabled / enabled";

done_testing;
