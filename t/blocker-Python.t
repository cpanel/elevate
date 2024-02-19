#!/usr/local/cpanel/3rdparty/bin/perl

use cPstrict;

use FindBin;

use lib "$FindBin::Bin/../lib";

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test::MockModule qw{strict};

use Elevate::Blockers::Python ();
use Elevate::OS               ();

my %mocks = map { $_ => Test::MockModule->new($_); } qw{
  Cpanel::Pkgr
  Elevate::Blockers
  Elevate::Blockers::Base
};
$mocks{'Cpanel::Pkgr'}->redefine( "what_provides" => '', "is_installed" => 1 );
my $obj = bless {}, 'Elevate::Blockers::Python';
ok( !$obj->check(), "Returns early on no provider of python36" );
$mocks{'Cpanel::Pkgr'}->redefine( "what_provides" => 'python3', "is_installed" => 0 );
ok( !$obj->check(), "Returns early on python36 not installed" );
$mocks{'Cpanel::Pkgr'}->redefine( "is_installed" => 1 );
$mocks{'Elevate::Blockers'}->redefine( "new" => sub { return bless {}, $_[0] } );
$mocks{'Elevate::Blockers::Base'}->redefine(
    "cpev" => sub { return bless {}, 'bogus::cpev' },
);
my $expected = {
    'id'  => 'Elevate::Blockers::Python::check',
    'msg' => <<~"END",
    A package providing python36 has been detected as installed.
    This can interfere with the elevation process.
    Please remove it before elevation:
    yum remove python3
    END
};
is( $obj->check, $expected, "Got expected blocker returned when found" );

done_testing();

# ------------------------------ #

package cpev;

sub read_stage_file {
    return 'CentOS7';
}
