#!perl

package Test::Elevate;

use cPstrict;
use Test::More;
use Test::Deep;

our @ISA       = qw(Exporter);
our @EXPORT    = qw(message_seen message_seen_lines clear_messages_seen no_messages_seen no_message_seen set_os_to_centos_7 set_os_to_cloudlinux_7 set_os_to unmock_os);
our @EXPORT_OK = @EXPORT;

use Log::Log4perl;

my @MESSAGES_SEEN;

BEGIN {
    if ( $INC{'Test/MockFile.pm'} ) {
        my $auth_pkg = Test::MockFile->can('authorized_strict_mode_for_package');
        $auth_pkg->('Cpanel::Logger') if $auth_pkg;
    }
    require $FindBin::Bin . q[/../elevate-cpanel];
    $INC{'cpev.pm'} = '__TEST__';
    no warnings;
    *Elevate::Logger::init = sub { };
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
    note 'Mock Elevate::OS singleton to think this server is CentOS 7';
    $Elevate::OS::OS = Elevate::OS::CentOS7->new();

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

sub set_os_to_centos_7 {
    note 'Mock Elevate::OS singleton to think this server is CentOS 7';
    $Elevate::OS::OS = Elevate::OS::CentOS7->new();
    return;
}

sub set_os_to_cloudlinux_7 {
    note 'Mock Elevate::OS singleton to think this server is CloudLinux 7';
    $Elevate::OS::OS = Elevate::OS::CloudLinux7->new();
    return;
}

sub set_os_to ($os) {
    return set_os_to_centos_7()   if $os =~ m/^cent/i;
    return set_os_to_cloudlinux_7 if $os =~ m/^cloud/i;

    die "Unknown os:  $os\n";
}

sub unmock_os {
    note 'Elevate::OS is no longer mocked';
    $Elevate::OS::OS = undef;
}

1;
