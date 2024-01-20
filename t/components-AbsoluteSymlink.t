use strict;
use warnings;

use FindBin;

use lib "$FindBin::Bin/../lib";

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test::MockModule qw{strict};
use Test::MockFile   qw{strict};

use Elevate::Components::AbsoluteSymlinks ();

my %mocks = map { $_ => Test::MockModule->new($_) } qw{Cpanel::Chdir Cpanel::UUID File::Copy};
$mocks{'Cpanel::Chdir'}->redefine( "new" => bless {}, "Stretchy::Pants" );
$mocks{'Cpanel::UUID'}->redefine( "random_uuid" => "what_u_mean" );
my %cabinet;
$cabinet{'/smang'} = Test::MockFile->symlink( "/home", "/smang" );

my $obj = bless {}, 'Elevate::Components::AbsoluteSymlinks';
ok( !$obj->post_leapp(), "Nothing to do post leapp" );
is( { $obj->get_abs_symlinks() }, { '/smang' => '/home' }, "Got expected from get_abs_symlinks" );
SKIP: {
    skip "Test::MockFile doesn't yet properly handle symlinks", 1;
    $cabinet{'/smang-what_u_mean'} = Test::MockFile->symlink( undef, "/smang-what_u_mean" );

    # Test::MockFile doesn't seem to know what to do about overwriting symlinks
    # so we need to help out File::Copy here
    $mocks{'File::Copy'}->redefine(
        "move" => sub {
            my ( $from, $to ) = @_;
            undef $cabinet{$to};
            my $tarjeta = $cabinet{$from}->readlink();
            $cabinet{$to} = Test::MockFile->symlink( $tarjeta, $to );
            undef $cabinet{$from};
            return 1;
        }
    );

    # XXX TODO figure out what the heck is needed to make the `symlink` builtin
    # in perl react properly to the existence of Test::MockModule->symlink objects
    # As it stands, this makes the symlink then bombs out with
    # 'readlink is only supported for symlinks'.
    $obj->pre_leapp();
    is( readlink("/smang"), 'home', "Symlink corrected by pre_leapp" );
}
done_testing();
