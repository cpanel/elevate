package Elevate::Logger;

=encoding utf-8

=head1 NAME

Elevate::Logger

Wrapper around Log4perl to initialize the elevate custom logger.

=cut

use cPstrict;

use Elevate::Constants ();

use Term::ANSIColor ();

use Log::Log4perl qw(:easy);

my %colors = (
    TRACE => 'cyan',
    DEBUG => 'bold white',
    INFO  => 'green',
    WARN  => 'yellow',
    ERROR => 'red',
    FATAL => 'bold red',
);

sub init ( $self, $debug_level = 'DEBUG' ) {
    my $log_file = Elevate::Constants::LOG_FILE;

    my $config = <<~"EOF";
        log4perl.appender.File=Log::Log4perl::Appender::File
        log4perl.appender.File.filename=$log_file
        log4perl.appender.File.syswrite=1
        log4perl.appender.File.layout=Log::Log4perl::Layout::PatternLayout
        log4perl.appender.File.layout.ConversionPattern=* %d{yyyy-MM-dd HH:mm:ss} (%L) [%s%p%u] %m%n
    EOF

    if ( $self->getopt('service') ) {
        $config .= <<~"EOF";
        log4perl.rootLogger = $debug_level, File
        EOF
    }
    else {
        $config .= <<~"EOF";
        log4perl.appender.Screen=Log::Log4perl::Appender::Screen
        log4perl.appender.Screen.stderr=0
        log4perl.appender.Screen.layout=Log::Log4perl::Layout::PatternLayout
        log4perl.appender.Screen.layout.ConversionPattern=* %d{yyyy-MM-dd HH:mm:ss} [%s%p%u] %m{indent=2,chomp}%n
        log4perl.rootLogger = $debug_level, Screen, File
        EOF
    }

    Log::Log4perl::Layout::PatternLayout::add_global_cspec( 's' => sub { Term::ANSIColor::color( $colors{ $_[3] } ) } );
    Log::Log4perl::Layout::PatternLayout::add_global_cspec( 'u' => sub { Term::ANSIColor::color('reset') } );

    Log::Log4perl->init( \$config );

    return;
}

sub INFO_nolog ($msg) {

    return _nolog( $msg, 'INFO' );
}

sub ERROR_nolog ($msg) {

    return _nolog( $msg, 'ERROR' );
}

sub WARN_nolog ($msg) {

    return _nolog( $msg, 'WARN' );
}

sub _nolog ( $msg, $type = 'DEBUG' ) {

    return unless length $msg;

    print '# -------------------------> [';
    print Term::ANSIColor::color( $colors{$type} );
    print $type;
    print Term::ANSIColor::color('reset');
    print '] ';
    print Term::ANSIColor::color('bold white');
    say $msg;
    print Term::ANSIColor::color('reset');

    return;
}

1;
