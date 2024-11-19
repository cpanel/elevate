package Elevate::Components::DiskSpace;

=encoding utf-8

=head1 NAME

Elevate::Components::DiskSpace

=head2 check

Verify server has enough disk space to perform elevation

=head2 pre_distro_upgrade

noop

=head2 post_distro_upgrade

noop

=cut

use cPstrict;

use Cpanel::SafeRun::Simple ();

use Elevate::OS ();

use parent qw{Elevate::Components::Base};

use Log::Log4perl qw(:easy);

use constant K   => 1;
use constant MEG => 1_024 * K;
use constant GIG => 1_024 * MEG;

sub check ($self) {    # $self is a cpev object here
    my $ok = _disk_space_check($self);
    $self->has_blocker(q[disk space issue]) unless $ok;

    return $ok;
}

sub _disk_space_check ($self) {

    # minimum disk space for some mount points
    # note we are not doing the sum per mount point
    #   - /boot is small enough
    #   - /usr/local/cpanel is not going to be used at the same time than /var/lib
    my $need_space = {
        '/boot'             => 200 * MEG,
        '/usr/local/cpanel' => 1.5 * GIG,    #
        '/var/lib'          => 5 * GIG,
        '/tmp'              => 5 * MEG,
        '/'                 => 5 * GIG,
    };

    my @keys = ( sort keys %$need_space );

    my @df_cmd = ( qw{/usr/bin/df -k}, @keys );
    my $cmd    = join( ' ', @df_cmd );

    my $result = Cpanel::SafeRun::Simple::saferunnoerror(@df_cmd) // '';
    die qq[Failed to check disk space using: $cmd\n] if $?;

    my ( $header, @out ) = split( "\n", $result );

    if ( scalar @out != scalar @keys ) {
        my $count_keys = scalar @keys;
        my $count_out  = scalar @out;
        die qq[Fail: Cannot parse df output from: $cmd\n] . "# expected $count_keys lines ; got $count_out lines\n" . join( "\n", @out ) . "\n";
    }

    my @errors;

    my $ix = 0;
    foreach my $line (@out) {
        my $key = $keys[ $ix++ ];
        my ( undef, undef, undef, $available ) = split( /\s+/, $line );

        my $need = $need_space->{$key};

        next if $available > $need;

        my $str;
        if ( $need / GIG > 1 ) {
            $str = sprintf( "- $key needs %2.2f G => available %2.2f G", $need / GIG, $available / GIG );
        }
        else {
            $str = sprintf( "- $key needs %d M => available %d M", $need / MEG, $available / MEG );
        }

        push @errors, $str;
    }

    # everything is fine: check ok
    return 1 unless @errors;

    my $details = join( "\n", @errors );

    my $pretty_distro_name = Elevate::OS::upgrade_to_pretty_name();

    my $error = <<"EOS";
** Warning **: your system does not have enough disk space available to update to $pretty_distro_name

$details
EOS

    warn $error . "\n";

    return 0;    # error
}

1;
