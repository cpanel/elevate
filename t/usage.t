#!/usr/local/cpanel/3rdparty/bin/perl

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockFile 0.032 qw<nostrict>;
use Test::MockModule qw/strict/;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;

use Elevate::Usage;

require $FindBin::Bin . '/../elevate-cpanel';

my $mock_usage = Test::MockModule->new('Elevate::Usage');

my $parse_results = {};

$mock_usage->redefine(
    help => sub {
        my ( $self, $msg, $exit_status ) = @_;
        $parse_results->{help_msg}    = $msg;
        $parse_results->{help_status} = $exit_status;
        return 0;
    },
    full_help => sub {
        $parse_results->{full_help_called} = 1;
    },
);

sub clear_parse_results {
    $parse_results = {};
}

sub test_expected_pass ( $options, $full_help = 0 ) {

    my $expected = {};
    $expected->{full_help_called} = 1 if $full_help;

    is $parse_results, $expected, "Passed with options: $options";
}

sub test_expected_fail ( $options, $fail_msg ) {

    my $expected = {
        help_msg    => $fail_msg,
        help_status => 1,
    };

    is $parse_results, $expected, "Expected failure ($fail_msg) with options: $options";
}

#
# This is an array of combinations of command line parameters along with
# the expected result of passing them into the script
#
# Each hash contains (or may contain):
# * options (required)  - list of command line options passed to the script
# * passed (required)   - whether the command line options should pass (or fail)
# * full_help           - whether the full help text should be displayed
# * fail_msg            - failure message emitted
# * warning_regex       - regex for any expected warnings
#

my @TEST_DATA = (
    {
        options => [qw//],
        passed  => 1,
    },
    {
        options   => [qw/--help/],
        passed    => 1,
        full_help => 1,
    },
    {
        options => [qw/--clean/],
        passed  => 1,
    },
    {
        options => [qw/--continue/],
        passed  => 1,
    },
    {
        options => [qw/--log/],
        passed  => 1,
    },
    {
        options => [qw/--service/],
        passed  => 1,
    },
    {
        options => [qw/--status/],
        passed  => 1,
    },
    {
        options => [qw/--update/],
        passed  => 1,
    },
    {
        options => [qw/--version/],
        passed  => 1,
    },
    {
        options => [qw/--start/],
        passed  => 1,
    },
    {
        options => [qw/--check/],
        passed  => 1,
    },
    {
        options       => [qw/--these --are --bogus/],
        passed        => 0,
        fail_msg      => 'Invalid Option',
        warning_regex => qr/Unknown option/,
    },
    {
        options       => [qw/--version --bogus/],
        passed        => 0,
        fail_msg      => 'Invalid Option',
        warning_regex => qr/Unknown option/,
    },
    {
        options       => [qw/--help --non-option/],
        passed        => 0,
        fail_msg      => 'Invalid Option',
        warning_regex => qr/Unknown option/,
    },
    {
        options  => [qw/--help --start/],
        passed   => 0,
        fail_msg => q/Option "help" is not compatible with any other option/,
    },
    {
        options  => [qw/--clean --service/],
        passed   => 0,
        fail_msg => q/Option "clean" is not compatible with any other option/,
    },
    {
        options  => [qw/--continue --no-leapp/],
        passed   => 0,
        fail_msg => q/Option "continue" is not compatible with any other option/,
    },
    {
        options  => [qw/--log --status/],
        passed   => 0,
        fail_msg => q/Option "log" is not compatible with any other option/,
    },
    {
        options  => [qw/--service --version --update/],
        passed   => 0,
        fail_msg => q/Option "service" is not compatible with any other option/,
    },
    {
        options  => [qw/--status --no-leapp/],
        passed   => 0,
        fail_msg => q/Option "status" is not compatible with any other option/,
    },
    {
        options  => [qw/--update --version/],
        passed   => 0,
        fail_msg => q/Option "update" is not compatible with any other option/,
    },
    {
        options  => [qw/--version --non-interactive/],
        passed   => 0,
        fail_msg => q/Option "version" is not compatible with any other option/,
    },
    {
        options       => [qw/--check --upgrade-to/],
        passed        => 0,
        fail_msg      => 'Invalid Option',
        warning_regex => qr/Option upgrade-to requires an argument/,
    },
    {
        options => [qw/--check --upgrade-to almalinux/],
        passed  => 1,
    },
    {
        options => [qw/--check --upgrade-to almalinux --skip-cpanel-version-check --skip-elevate-version-check --no-leapp/],
        passed  => 1,
    },
    {
        options  => [qw/--check --non-interactive/],
        passed   => 0,
        fail_msg => q/Option "non-interactive" is only compatible with "start"/,
    },
    {
        options  => [qw/--check --manual-reboots/],
        passed   => 0,
        fail_msg => q/Option "manual-reboots" is only compatible with "start"/,
    },
    {
        options  => [qw/--check --start/],
        passed   => 0,
        fail_msg => q/The options "start" and "check" are mutually exclusive/,
    },
    {
        options  => [qw/--start --check/],
        passed   => 0,
        fail_msg => q/The options "start" and "check" are mutually exclusive/,
    },
    {
        options       => [qw/--start --upgrade-to/],
        passed        => 0,
        fail_msg      => 'Invalid Option',
        warning_regex => qr/Option upgrade-to requires an argument/,
    },
    {
        options => [qw/--start --upgrade-to rocky  --skip-cpanel-version-check --skip-elevate-version-check --no-leapp --manual-reboots --non-interactive/],
        passed  => 1,
    },
);

foreach my $test_hr (@TEST_DATA) {

    clear_parse_results();

    my $usage = bless {}, 'Elevate::Usage';
    my $warnings_emitted = warnings { $usage->init( @{ $test_hr->{options} } ) };

    my $options = join ' ', @{ $test_hr->{options} };

    if ( $test_hr->{passed} ) {
        test_expected_pass( $options, $test_hr->{full_help} );
    }
    else {
        test_expected_fail( $options, $test_hr->{fail_msg} );
    }

    if ( exists $test_hr->{warning_regex} ) {
        like $warnings_emitted, [ $test_hr->{warning_regex} ], "Expected warnings for: $options";
    }
    else {
        is $warnings_emitted, [], "No warnings for: $options";
    }
}

#
# Test out setting --upgrade-to to different values
#

{
    note 'Test as CentOS 7 server';

    set_os_to_centos_7();

    my $cpev = cpev->new->_init( '--check', '--upgrade-to=OogaBoogaLinux' );

    like(
        dies { $cpev->_parse_opt_upgrade_to() },
        qr/The current OS can only upgrade to the following flavors/,
        'Exception thrown for invalid linux distro'
    );

    $cpev = cpev->new->_init('--check');

    ok lives { $cpev->_parse_opt_upgrade_to() }, 'No exception when upgrade-to not supplied';
    is $cpev->upgrade_to(), 'AlmaLinux', 'CentOS 7 defaults to AlmaLinux when upgrade-to not specified';

    $cpev = cpev->new->_init( '--check', '--upgrade-to=almalinux' );

    ok lives { $cpev->_parse_opt_upgrade_to() }, 'No exception when upgrade-to set to AlmaLinux';
    is $cpev->upgrade_to(), 'AlmaLinux', 'Set to use AlmaLinux when upgrade-to set to AlmaLinux';

    $cpev = cpev->new->_init( '--check', '--upgrade-to=rocky' );

    ok lives { $cpev->_parse_opt_upgrade_to() }, 'No exception when upgrade-to set to Rocky';
    is $cpev->upgrade_to(), 'Rocky', 'Set to use Rocky when upgrade-to set to Rocky';

    $cpev = cpev->new->_init( '--check', '--upgrade-to=cloudlinux' );

    like(
        dies { $cpev->_parse_opt_upgrade_to() },
        qr/The current OS can only upgrade to the following flavors/,
        'Exception thrown for CloudLinux when the OS is CentOS 7',
    );

}

{
    note 'Test as CloudLinux 7 server';

    set_os_to_cloudlinux_7();

    my $cpev = cpev->new->_init('--check');

    ok lives { $cpev->_parse_opt_upgrade_to() }, 'No exception when upgrade-to not supplied';
    is $cpev->upgrade_to(), 'CloudLinux', 'CloudLinux 7 defaults to CloudLinux when upgrade-to not specified';

    $cpev = cpev->new->_init( '--check', '--upgrade-to=almalinux' );

    like(
        dies { $cpev->_parse_opt_upgrade_to() },
        qr/The current OS can only upgrade to the following flavors/,
        'Exception thrown for AlmaLinux when the OS is CloudLinux 7',
    );

    $cpev = cpev->new->_init( '--check', '--upgrade-to=rocky' );

    like(
        dies { $cpev->_parse_opt_upgrade_to() },
        qr/The current OS can only upgrade to the following flavors/,
        'Exception thrown for Rocky Linux when the OS is CloudLinux 7',
    );

    $cpev = cpev->new->_init( '--check', '--upgrade-to=cloudlinux' );

    ok lives { $cpev->_parse_opt_upgrade_to() }, 'No exception when upgrade-to set to cloudlinux';
    is $cpev->upgrade_to(), 'CloudLinux', 'Set to use CloudLinux when upgrade-to set to CloudLinux';

}

#
# Test out the --non-interactive parameter
#

my $user_has_been_prompted = 0;

my $mock_io_prompt = Test::MockModule->new('IO::Prompt');
$mock_io_prompt->redefine(
    prompt => sub {
        $user_has_been_prompted = 1;
        return 1;
    }
);

my $cpev = cpev->new->_init('--start');
$cpev->give_last_chance();
is $user_has_been_prompted, 1, 'IP::Prompt invoked without the non-interactive option';

$user_has_been_prompted = 0;
$cpev                   = cpev->new->_init( '--start', '--non-interactive' );
$cpev->give_last_chance();
is $user_has_been_prompted, 0, 'IP::Prompt not invoked with the non-interactive option';

done_testing();
exit;
