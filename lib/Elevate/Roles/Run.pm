package Elevate::Roles::Run;

use cPstrict;

use Cpanel::IOCallbackWriteLine ();
use Cpanel::SafeRun::Object     ();

use Log::Log4perl qw(:easy);

sub ssystem_capture_output ( $, @args ) {

    my %opts;
    if ( ref $args[0] ) {
        my $ropts = shift @args;
        %opts = %$ropts;
    }
    $opts{should_capture_output} = 1;

    return _ssystem( \@args, %opts );
}

sub ssystem ( $, @args ) {

    my %opts;
    if ( ref $args[0] ) {
        my $ropts = shift @args;
        %opts = %$ropts;
    }

    return _ssystem( \@args, %opts );
}

sub ssystem_and_die ( $self, @args ) {
    $self->ssystem(@args) or return 0;
    die "command failed. Fix it and run command.";
}

sub _ssystem ( $command, %opts ) {
    my @args = @{ $command // [] };
    INFO( "Running: " . join( " ", @args ) );
    INFO();    # Buffer so they can more easily read the output.

    # emulate shell behavior of system()
    if ( scalar @args == 1 && $args[0] =~ m/[\$&*(){}\[\]'";\\|?<>~`\n]/ ) {
        unshift @args, qw(/usr/bin/bash -c);
    }

    my $capture_output = { stdout => [], stderr => [] };
    my $program        = shift @args;
    my ( $callback_out, $callback_err ) = map {
        my $label = $_;
        Cpanel::IOCallbackWriteLine->new(
            sub ($line) {
                chomp $line;
                INFO($line);
                if ( $opts{should_capture_output} ) {
                    push $capture_output->{$label}->@*, $line;
                }
                return;
            }
        )
    } qw(stdout stderr);
    my $sr = Cpanel::SafeRun::Object->new(
        program      => $program,
        args         => [@args],
        stdout       => $callback_out,
        stderr       => $callback_err,
        timeout      => 0,
        keep_env     => $opts{keep_env} // 0,
        read_timeout => 0,
    );
    INFO();    # Buffer so they can more easily read the output.

    $? = $sr->CHILD_ERROR;    ## no critic qw(Variables::RequireLocalizedPunctuationVars) -- emulate return behavior of system()

    if ( $opts{should_capture_output} ) {
        $capture_output->{status} = $?;
        return $capture_output;
    }

    return $?;
}

1;
