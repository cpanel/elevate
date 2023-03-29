#!/usr/local/cpanel/3rdparty/bin/perl

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockFile   qw/strict/;
use Test::MockModule qw/strict/;

use File::Slurper qw{read_text};

use lib $FindBin::Bin . "/lib", $FindBin::Bin . "/../lib";

#use Elevate::Service ();

use Test::Elevate;

note $INC{'Elevate/Service.pm'};

use cPstrict;
require $FindBin::Bin . '/../elevate-cpanel';

my @messages_seen;

ok cpev::IGNORE_OUTDATED_SERVICES_FILE(), 'IGNORE_OUTDATED_SERVICES_FILE';

my $service      = Elevate::Service->new->short_name;
my $shortservice = $service;
$shortservice =~ s{\.service}{};

my $outdated_file = cpev::IGNORE_OUTDATED_SERVICES_FILE();
my $dirname       = File::Basename::dirname($outdated_file);

my $mock_dir = Test::MockFile->dir($dirname);

my $mock_ignore_file = Test::MockFile->file($outdated_file);

ok !-d $dirname,       "dir does not exist";
ok !-f $outdated_file, "outdated_file does not exist";

ok( cpev->setup_outdated_services(), 'setup_outdated_services - set service' );

ok -d $dirname,       'dir created';
ok -f $outdated_file, 'file created';

is read_text($outdated_file), qq[$shortservice\n], "content set to service";

is( cpev->restore_outdated_services(), 2, "restore_outdated_services - remove service and file" );
ok -d $dirname,        'dir preserved';
ok !-f $outdated_file, 'file removed';

my @tests = (

    {
        starts_with                  => qq[service-one],
        expect_content_after_setup   => qq[service-one\n$service\n],
        expect_content_after_restore => qq[service-one\n],
    },

    {
        starts_with                  => qq[service-one\n],
        expect_content_after_setup   => qq[service-one\n$service\n],
        expect_content_after_restore => qq[service-one\n],
    },

    {
        starts_with                  => qq[service-one\nservice-two],
        expect_content_after_setup   => qq[service-one\nservice-two\n$service\n],
        expect_content_after_restore => qq[service-one\nservice-two\n],
    },

    {
        starts_with                  => qq[],
        expect_content_after_setup   => qq[$service\n],
        expect_content_after_restore => undef,
    },

    {
        starts_with                  => qq[   \n\n\n  \n\n],
        expect_content_after_setup   => qq[   \n\n\n  \n\n$service\n],
        expect_content_after_restore => undef,
    },

    {
        starts_with                  => qq[$service\n],
        expect_content_after_setup   => qq[$service\n],
        expect_content_after_restore => undef,
    },

    {
        starts_with                  => qq[$service\n\n\n$service\n],
        expect_content_after_setup   => qq[$service\n\n\n$service\n],
        expect_content_after_restore => undef,
    },

    {
        starts_with                  => qq[$service\n\nfoo\n\n$service\n],
        expect_content_after_setup   => qq[$service\n\nfoo\n\n$service\n],
        expect_content_after_restore => qq[\n\nfoo\n],
    },
);

foreach my $t (@tests) {
    note "test with: content = [", $t->{starts_with}, ']';

    $mock_ignore_file->contents( $t->{starts_with} );

    cpev->setup_outdated_services();

    is read_text($outdated_file), $t->{expect_content_after_setup}, "expect_content_after_setup";

    cpev->restore_outdated_services();

    if ( defined $t->{expect_content_after_restore} ) {
        is read_text($outdated_file), $t->{expect_content_after_restore}, "expect_content_after_restore";
    }
    else {
        ok !-f $outdated_file, "outdated_file removed";
    }
}

done_testing;
