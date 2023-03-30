#!/usr/local/cpanel/3rdparty/bin/perl

package test::cpev::blockers;

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockFile 0.032;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use Test::MockModule qw/strict/;

use Cpanel::JSON;

use cPstrict;

my $log_file = Test::MockFile->file('/var/log/elevate-cpanel.log');
my $mock_www = Test::MockFile->file('/etc/wwwacct.conf');

my $cpev = cpev->new->_init;

cpev::DEBUG("This is a DEBUG message...");
cpev::INFO("This is an INFO message");
cpev::WARN("This is a warning!");
cpev::ERROR("This is an error");
cpev::FATAL("This is FATAL!");

cpev::INFO("This is a\nmultilines\nmessages....\n");

pass "survives";

done_testing();
