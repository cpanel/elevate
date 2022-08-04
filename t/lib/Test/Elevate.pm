#!perl

package Test::Elevate;

use cPstrict;
use Test::More;
use Test::Deep;

our @ISA       = qw(Exporter);
our @EXPORT    = qw(message_seen message_seen_lines clear_messages_seen no_messages_seen no_message_seen );
our @EXPORT_OK = @EXPORT;

use Log::Log4perl;

my @MESSAGES_SEEN;

BEGIN {
    if ($INC{'Test/MockFile.pm'}) {
        my $auth_pkg = Test::MockFile->can('authorized_strict_mode_for_package');
        $auth_pkg->('Cpanel::Logger') if $auth_pkg;
    }
    require $FindBin::Bin . q[/../elevate-cpanel];
    $INC{'cpev.pm'} = '__TEST__';
}

sub _msg ( $self, $msg, $level ) {
    note "MockedLogger [$level] $msg";
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

    my $config = <<~'EOS';
    log4perl.category = DEBUG, MyTest

    log4perl.appender.MyTest=Log::Log4perl::Appender::TestBuffer
    log4perl.appender.MyTest.name=mybuffer
    log4perl.appender.MyTest.layout=Log::Log4perl::Layout::SimpleLayout

    EOS
    Log::Log4perl->init( \$config );

    my $log = Log::Log4perl::get_logger('cpev');
    $log->{$_} = \&_msg for qw{ALL DEBUG ERROR FATAL INFO OFF TRACE WARN};
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

1;
