#!/usr/local/cpanel/3rdparty/bin/perl

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use cPstrict;

use Test::MockModule qw/strict/;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use File::Temp ();

my $cpev_mock = Test::MockModule->new('cpev');
my $cpev      = bless {}, 'cpev';

subtest "test behavior when the directory doesn't exist" => sub {
    my $exception = dies { cpev::_parse_shell_variable( '/this/path/does/not/exist', 'GRUB_ENABLE_BLSCFG' ) };
    isa_ok( $exception, 'Cpanel::Exception::ProcessFailed::Error' );
    is( eval { $exception->get('error_code') }, 72, "expected return status" );
};

my $test_file = File::Temp->new;
$test_file->autoflush(1);

chown( scalar getpwnam('nobody'), scalar getgrnam('nobody'), $test_file );

is( cpev::_parse_shell_variable( $test_file->filename, 'GRUB_ENABLE_BLSCFG' ), undef, "_parse_shell_variable returns undef if the variable does not exist in the file" );

$test_file->print("GRUB_ENABLE_BLSCFG=true\n");
is( cpev::_parse_shell_variable( $test_file->filename, 'GRUB_ENABLE_BLSCFG' ), 'true', "_parse_shell_variable handles bare values" );

$test_file->seek( 0, 0 );
$test_file->print("GRUB_ENABLE_BLSCFG=\"true\"\n");
is( cpev::_parse_shell_variable( $test_file->filename, 'GRUB_ENABLE_BLSCFG' ), 'true', "_parse_shell_variable handles double-quoted values" );

done_testing;
