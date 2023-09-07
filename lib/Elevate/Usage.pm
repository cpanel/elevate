package Elevate::Usage;

=encoding utf-8

=head1 NAME

Elevate::Usage - handle options for the elevate script

Simplified version of Cpanel::HelpfulScript for elevate

=cut

use cPstrict;

use Getopt::Long ();

sub _OPTIONS {
    return qw(
      help
      service start clean continue manual-reboots status log check:s
      skip-cpanel-version-check skip-elevate-version-check
      update version
      upgrade-to=s
      no-leapp
    );
}

sub init ( $self, @args ) {

    $self->{_getopt} = {};

    Getopt::Long::GetOptionsFromArray(
        \@args,
        $self->{_getopt},
        _OPTIONS()
    ) or return $self->help( "Invalid Option", 1 );

    return $self->full_help() if $self->getopt('help');
}

sub getopt ( $self, $k ) {
    return $self->{_getopt}->{$k};
}

=head2 I<OBJ>->help( $MESSAGE )

Returns the usage instructions as L<Pod::Usage> formats them.

$MESSAGE is given to Pod::Usage as its C<-message>.

=cut

sub help ( $self, $msg = undef, $exit_status = undef ) {
    say $self->_help($msg);
    exit( $exit_status // 0 );
}

=head2 I<OBJ>->full_help( $MESSAGE )

Returns the full L<Pod::Usage> output (not just usage).

$MESSAGE is treated as in C<help()>.

=cut

sub full_help ( $self, $msg = undef, $exit_status = undef ) {

    my $out = $self->_help( $msg, 2 );
    my ( $short_help, $extra ) = split( qr{^.+STAGES}m, $out );
    my @lines = split "\n", $short_help;
    shift @lines for 1 .. 2;
    say foreach @lines;
    exit( $exit_status // 0 );
}

sub _help ( $class, $msg = undef, $verbosity = undef ) {

    my $val;
    open my $wfh, '>', \$val or die "Failed to open to a scalar: $!";

    $msg .= "\n" if length $msg;

    local $Pod::Usage::Formatter;
    $Pod::Usage::Formatter = 'Pod::Text::Termcap' if _stdout_is_terminal();

    #We have to defer loading Pod::Usage in order to control
    #how it formats output.
    require 'Pod/Usage.pm';    ##no critic qw(RequireBarewordIncludes)

    my $pod_path = $0;

    'Pod::Usage'->can('pod2usage')->(
        -exitval   => 'NOEXIT',
        -message   => $msg,
        -verbose   => $verbosity,
        -noperldoc => 1,
        -output    => $wfh,
        -input     => $pod_path,
    );

    warn "No POD for “$class” in “$pod_path”!" if !$val;

    return $val;
}

sub _stdout_is_terminal() { return -t \*STDOUT }

1;
