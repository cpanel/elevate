#!/usr/local/cpanel/3rdparty/bin/perl

# HARNESS-NO-STREAM

# cpanel - ./t/pecl.t                              Copyright 2022 cPanel, L.L.C.
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockModule qw/strict/;

use Test::MockFile;
use Log::Log4perl;

use FindBin;

require $FindBin::Bin . q[/../elevate-cpanel];

use cPstrict;

$INC{'scripts/ElevateCpanel.pm'} = '__TEST__';

my $config = <<'EOS';
log4perl.category = DEBUG, MyTest

log4perl.appender.MyTest=Log::Log4perl::Appender::TestBuffer
log4perl.appender.MyTest.name=mybuffer
log4perl.appender.MyTest.layout=Log::Log4perl::Layout::SimpleLayout

EOS
Log::Log4perl->init( \$config );

my @messages_seen;

sub _msg ( $self, $msg, $level ) {
    note "MockedLogger [$level] $msg";
    push @messages_seen, [ $level, $msg ];
    return;
}

my $log = Log::Log4perl::get_logger('cpev');
$log->{$_} = \&_msg for qw{ALL DEBUG ERROR FATAL INFO OFF TRACE WARN};

my $mock_elevate = Test::MockModule->new('cpev');

my $mock_stage_file = Test::MockFile->file( cpev::ELEVATE_STAGE_FILE() );

my $list_output;

my $mock_saferun = Test::MockModule->new('Cpanel::SafeRun::Simple');
$mock_saferun->redefine(
    saferunnoerror => sub {
        return $list_output;

    }
);

my $pecl_bin = Test::MockFile->file( '/my/pecl/bin', '', { mode => 0700 } );

is cpev::_get_pecl_installed_for('/my/pecl/bin'), undef, '_get_pecl_installed_for - empty list';

$list_output = qq[(no packages installed from channel pecl.php.net)\n];

is cpev::_get_pecl_installed_for('/my/pecl/bin'), undef, '_get_pecl_installed_for - no packages installed';

$list_output = <<'EOS';
Installed packages, channel pecl.php.net:
=========================================
Package Version State
imagick 3.5.1   stable
EOS

is cpev::_get_pecl_installed_for('/my/pecl/bin'), {
    imagick => q[3.5.1],
  },
  '_get_pecl_installed_for - imagick';

$list_output = <<'EOS';
Installed packages, channel pecl.php.net:
=========================================
Package Version State
ds      1.4.0   stable
imagick 3.5.1   stable
EOS

is cpev::_get_pecl_installed_for('/my/pecl/bin'), {
    ds      => q[1.4.0],
    imagick => q[3.5.1],
  },
  '_get_pecl_installed_for - ds + imagick';

{

    is cpev::read_stage_file(), {}, "stage file is empty";

    $mock_elevate->redefine( _get_pecl_installed_for => sub { { module_one => 1.2 } } );

    cpev::_store_pecl_for( '/whatever', 'cpanel' );

    is cpev::read_stage_file(), { pecl => { cpanel => { module_one => 1.2 } } }, "stage file: store pecl for cpanel";

    $mock_elevate->redefine( _get_pecl_installed_for => sub { { xyz => 5.6 } } );
    cpev::_store_pecl_for( '/whatever', 'ea-php80' );

    is cpev::read_stage_file(), {
        pecl => {
            cpanel     => { module_one => 1.2 },
            'ea-php80' => { xyz        => 5.6 }
        }
      },
      "stage file: store pecl for cpanel & ea-php80";

}

{
    $mock_elevate->redefine( _get_pecl_installed_for => undef );
    $mock_elevate->redefine(
        read_stage_file => sub {
            return {
                pecl => {
                    cpanel => {
                        module_one => 1.2,
                        module_two => 2.2,
                    },

                }
            };
        }
    );

    @messages_seen = ();

    cpev::check_pecl_packages();

    message_seen_lines( 'WARN', <<'EOS' );
********************
WARNING: Missing pecl package(s) for /usr/local/cpanel/3rdparty/bin/pecl
Please reinstall these packages
********************
- module_one
- module_two
#
EOS

    $mock_elevate->redefine(
        _get_pecl_installed_for => sub {
            return { module_one => 1.2 },;
        }
    );

    @messages_seen = ();
    cpev::check_pecl_packages();

    message_seen_lines( 'WARN', <<'EOS' );
********************
WARNING: Missing pecl package(s) for /usr/local/cpanel/3rdparty/bin/pecl
Please reinstall these packages
********************
- module_two
#
EOS

}

done_testing;

sub message_seen_lines ( $type, $msg ) {
    my @lines = split( /\n/, $msg );
    foreach my $l (@lines) {
        message_seen( $type, $l );
    }

    return;
}

sub message_seen ( $type, $msg ) {
    my $line = shift @messages_seen;
    if ( ref $line ne 'ARRAY' ) {
        fail("    No message of type '$type' was emitted.");
        fail("    With output: $msg");
        return 0;
    }

    my $type_seen = $line->[0] // '';
    $type_seen =~ s/^\s+//;
    $type_seen =~ s/: //;

    is( $type_seen, $type, "  |_  Message type is $type" );
    if ( ref $msg eq 'Regexp' ) {
        like( $line->[1], $msg, "  |_  Message string is expected." );
    }
    else {
        is( $line->[1], $msg, "  |_  Message string is expected." );
    }

    return;
}
