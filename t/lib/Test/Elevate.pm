#!perl

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

package Test::Elevate;

use cPstrict;
use Test::More;
use Test::Deep;

our @ISA = qw(Exporter);

our @EXPORT = qw(
  clear_messages_seen
  clear_notifications_seen
  message_seen
  message_seen_lines
  no_message_seen
  no_messages_seen
  no_notification_seen
  no_notifications_seen
  notification_seen
  set_os_to_almalinux_8
  set_os_to_almalinux_9
  set_os_to_centos_7
  set_os_to_cloudlinux_7
  set_os_to_cloudlinux_8
  set_os_to_ubuntu_20
  set_os_to_ubuntu_22
  set_os_to
  unmock_os
);

our @EXPORT_OK = @EXPORT;

use Log::Log4perl;

my @MESSAGES_SEEN;
my @NOTIFICATIONS_SEEN;

BEGIN {
    if ( $INC{'Test/MockFile.pm'} ) {
        my $auth_pkg = Test::MockFile->can('authorized_strict_mode_for_package');
        $auth_pkg->('Cpanel::Logger') if $auth_pkg;
    }
    require $FindBin::Bin . q[/../elevate-cpanel];
    $INC{'cpev.pm'} = '__TEST__';
    no warnings;
    *Elevate::Logger::init               = sub { };
    *Elevate::OS::_set_cache             = sub { };
    *Elevate::Notify::_send_notification = sub {
        my %notification;
        $notification{subject} = shift;
        $notification{msg}     = shift;
        $notification{opts}    = {@_};

        push @NOTIFICATIONS_SEEN, \%notification;

        return;
    };
}

sub _msg ( $self, $msg, $level = '[void]' ) {
    if ( $level eq '[void]' ) {
        $level = $msg;
        $msg   = '';
    }
    note "MockedLogger [$level] $msg ";
    push @MESSAGES_SEEN, [ $level, $msg ];
    return;
}

INIT {
    init();
}

sub init {
    state $once;

    return if $once;
    $once = 1;

    note "init Log4perl for testing";

    my $config = <<~'EOS';
    log4perl.category = DEBUG, MyTest
    log4perl.appender.MyTest=Log::Log4perl::Appender::TestBuffer
    log4perl.appender.MyTest.name=mybuffer
    log4perl.appender.MyTest.layout=Log::Log4perl::Layout::SimpleLayout

    EOS
    Log::Log4perl->init( \$config );

    mockLoggerFor('');
    mockLoggerFor('cpev');

    # we should use a single logger and rootLogger....
    my @elevate = grep { m{^Elevate/} } sort keys %INC;
    foreach my $cat (@elevate) {
        $cat =~ s{\Q.pm\E$}{};
        $cat =~ s{/}{.}g;
        mockLoggerFor($cat);
    }

    # Default to CentOS 7
    note 'Mock Elevate::OS singleton to think this server is AlmaLinux 8';
    $Elevate::OS::OS = bless {}, 'Elevate::OS::AlmaLinux8';

    return;
}

sub mockLoggerFor ($pkg) {
    $pkg //= '';    # default to root logger
    my $log = Log::Log4perl::get_logger($pkg);
    $log->{$_} = \&_msg for qw{ALL DEBUG ERROR FATAL INFO OFF TRACE WARN};

    return;
}

sub message_seen_lines ( $type, $msg ) {
    my @lines = split( /\n/, $msg );
    foreach my $l (@lines) {
        message_seen( $type, $l );
    }

    return;
}

sub clear_messages_seen() {
    @MESSAGES_SEEN = ();
    return;
}

sub message_seen ( $type, $msg ) {
    my $line = shift @MESSAGES_SEEN;
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

sub no_messages_seen {
    is_deeply( \@MESSAGES_SEEN, [], 'No messages are remaining.' ) || diag explain \@MESSAGES_SEEN;

    clear_messages_seen();

    return;
}

# convenience
sub no_message_seen { goto &no_messages_seen; }

sub clear_notifications_seen () {
    @NOTIFICATIONS_SEEN = ();
    return;
}

sub notification_seen ( $subject, $msg, %opts ) {
    my $notification = shift @NOTIFICATIONS_SEEN;
    if ( ref $notification ne 'HASH' ) {
        fail("    What was collected did not look like a notification.");
        return 0;
    }

    my ( $subject_seen, $msg_seen ) = $notification->@{qw(subject msg)};
    my $opts_seen = $notification->{opts};

    if ( ref $subject eq 'Regexp' ) {
        like( $subject_seen, $subject, "  |_  Subject string is expected." );
    }
    else {
        is( $subject_seen, $subject, "  |_  Subject string is expected." );
    }
    if ( ref $msg eq 'Regexp' ) {
        like( $msg_seen, $msg, "  |_  Message string is expected." );
    }
    else {
        is( $msg_seen, $msg, "  |_  Message string is expected." );
    }
    is_deeply( $opts_seen, \%opts, "  |_  Options hash is expected." );

    return;
}

sub no_notifications_seen {
    is_deeply( \@NOTIFICATIONS_SEEN, [], 'No notifications are remaining.' ) || diag explain \@NOTIFICATIONS_SEEN;

    clear_notifications_seen();

    return;
}

# convenience
sub no_notification_seen { goto &no_notifications_seen; }

sub set_os_to_centos_7 {
    note 'Mock Elevate::OS singleton to think this server is CentOS 7';
    $Elevate::OS::OS = bless {}, 'Elevate::OS::CentOS7';
    return;
}

sub set_os_to_cloudlinux_7 {
    note 'Mock Elevate::OS singleton to think this server is CloudLinux 7';
    $Elevate::OS::OS = bless {}, 'Elevate::OS::CloudLinux7';
    return;
}

sub set_os_to_almalinux_8 {
    note 'Mock Elevate::OS singleton to think this server is AlmaLinux 8';
    $Elevate::OS::OS = bless {}, 'Elevate::OS::AlmaLinux8';
    return;
}

sub set_os_to_almalinux_9 {
    note 'Mock Elevate::OS singleton to think this server is AlmaLinux 9';
    $Elevate::OS::OS = bless {}, 'Elevate::OS::AlmaLinux9';
    return;
}

sub set_os_to_cloudlinux_8 {
    note 'Mock Elevate::OS singleton to think this server is CloudLinux 8';
    $Elevate::OS::OS = bless {}, 'Elevate::OS::CloudLinux8';
    return;
}

sub set_os_to_ubuntu_20 {
    note 'Mock Elevate::OS singleton to think this server is Ubuntu 20';
    $Elevate::OS::OS = bless {}, 'Elevate::OS::Ubuntu20';
    return;
}

sub set_os_to_ubuntu_22 {
    note 'Mock Elevate::OS singleton to think this server is Ubuntu 22';
    $Elevate::OS::OS = bless {}, 'Elevate::OS::Ubuntu22';
    return;
}

sub set_os_to ( $os, $version ) {
    return set_os_to_centos_7     if $os =~ m/^cent/i   && $version == 7;
    return set_os_to_cloudlinux_7 if $os =~ m/^cloud/i  && $version == 7;
    return set_os_to_almalinux_8  if $os =~ m/^alma/i   && $version == 8;
    return set_os_to_almalinux_9  if $os =~ m/^alma/i   && $version == 9;
    return set_os_to_cloudlinux_8 if $os =~ m/^cloud/i  && $version == 8;
    return set_os_to_ubuntu_20    if $os =~ m/^ubuntu/i && $version == 20;
    return set_os_to_ubuntu_22    if $os =~ m/^ubuntu/i && $version == 22;

    die "Unknown os:  $os $version\n";
}

sub unmock_os {
    note 'Elevate::OS is no longer mocked';
    $Elevate::OS::OS = undef;
}

1;
