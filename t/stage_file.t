#!/usr/local/cpanel/3rdparty/bin/perl

# HARNESS-NO-STREAM

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockModule qw/strict/;

use FindBin;

use Test::MockFile 0.032;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

my $mock_elevate = Test::MockModule->new('cpev');

my $mock_stage_file = Test::MockFile->file( cpev::ELEVATE_STAGE_FILE() );

is cpev::read_stage_file(),            {}, 'read_stage_file empty file';
is cpev::read_stage_file('something'), {}, 'read_stage_file("something") = {}';
is cpev::read_stage_file( 'something', 0 ),     0,     'read_stage_file("something", 0) = 0';
is cpev::read_stage_file( 'something', 42 ),    42,    'read_stage_file("something", 42) = 43';
is cpev::read_stage_file( 'something', [] ),    [],    'read_stage_file("something", []) = []';
is cpev::read_stage_file( 'something', undef ), undef, 'read_stage_file("something", undef) = undef';

ok cpev::save_stage_file( { fruits => ['cherry'] } ), 'save_stage_file';
is cpev::read_stage_file(), { fruits => ['cherry'] }, 'read_stage_file';
is cpev::read_stage_file('fruits'), ['cherry'], 'read_stage_file("fruits")';

ok cpev::update_stage_file( { veggies => ['carrots'] } ), 'update_stage_file';
is cpev::read_stage_file(), { fruits => ['cherry'], veggies => ['carrots'] }, 'read_stage_file';

$mock_stage_file->contents('');
is cpev::read_stage_file(), {}, 'read_stage_file empty file';

ok cpev::update_stage_file( { ea4 => { profile => q[myprofile] } } ), 'update_stage_file: ea4 profile';
ok cpev::update_stage_file( { ea4 => { enable  => 1 } } ),            'update_stage_file: ea4 enable';

is cpev::read_stage_file(), { ea4 => { profile => q[myprofile], enable => 1 } }, 'read_stage_file merging hashes';

{
    note "bumping the stage";

    $mock_stage_file->contents('');

    is cpev::get_stage(), 0, 'stage 0';
    ok( cpev->bump_stage(), 'bump_stage' );

    is cpev::get_stage(), 1, 'stage 1';
    ok( cpev->bump_stage(), 'bump_stage' );

    is cpev::get_stage(), 2, 'stage 2';
    ok( cpev->bump_stage(), 'bump_stage' );

    ok cpev::update_stage_file( { key => 'value' } ), 'update_stage_file: add an extra entry';

    is cpev::get_stage(), 3, 'stage 3';
    is cpev::read_stage_file(), { stage_number => 3, key => 'value' }, 'read_stage_file: stage is preserved';
}

subtest 'read / delete' => sub {
    $mock_stage_file->contents('');

    ok cpev::save_stage_file( { root => { fruits => [qw/banana/], veggies => [qw/carrot/] } } ), 'save_stage_file';
    is cpev::read_stage_file(), { root => { fruits => ['banana'], veggies => ['carrot'] } }, 'read_stage_file';

    ok cpev::update_stage_file( { root => { fruits => [qw/cherry/] } } ), 'update_stage_file';
    is cpev::read_stage_file(), { root => { fruits => [qw{cherry banana}], veggies => ['carrot'] } }, 'update_stage_file merge...'
      or diag explain cpev::read_stage_file();

    ok cpev::remove_from_stage_file('root.fruits'), "can remove root.fruits";
    is cpev::read_stage_file(), { root => { veggies => ['carrot'] } }, 'fruits entry was removed'
      or diag explain cpev::read_stage_file();

    ok cpev::update_stage_file( { root => { fruits => [qw/cherry/] } } ), 'update_stage_file';
    is cpev::read_stage_file(), { root => { fruits => [qw{cherry}], veggies => ['carrot'] } }, 'update_stage_file after a partial cleanup'
      or diag explain cpev::read_stage_file();

    ok cpev::remove_from_stage_file('root'), "can remove root";
    is cpev::read_stage_file(), {}, 'removed root entry'
      or diag explain cpev::read_stage_file();

    ok cpev::save_stage_file( { root => { levelone => { leveltwo => {qw/bla bla/} }, veggies => [qw/carrot/] } } ), 'save_stage_file';
    is cpev::read_stage_file(),
      {
        'root' => {
            'levelone' => { 'leveltwo' => { 'bla' => 'bla' } },
            'veggies'  => ['carrot']
        }
      },
      'check stage file'
      or diag explain cpev::read_stage_file();

    ok !cpev::remove_from_stage_file('not-there'),      "nothing to remove";
    ok !cpev::remove_from_stage_file('root.not-there'), "nothing to remove";

    is cpev::read_stage_file(),
      {
        'root' => {
            'levelone' => { 'leveltwo' => { 'bla' => 'bla' } },
            'veggies'  => ['carrot']
        }
      },
      'check stage file'
      or diag explain cpev::read_stage_file();

    ok cpev::remove_from_stage_file('root.levelone.leveltwo'), "remove root.levelone.leveltwo";
    is cpev::read_stage_file(),
      {
        'root' => {
            'levelone' => {},
            'veggies'  => ['carrot']
        }
      },
      'check stage file'
      or diag explain cpev::read_stage_file();

    ok cpev::remove_from_stage_file('root'), "remove root";
    is cpev::read_stage_file(), {}, 'removed root entry'
      or diag explain cpev::read_stage_file();
    ok !cpev::remove_from_stage_file('root'), "cannot remove root twice";

};

done_testing;
