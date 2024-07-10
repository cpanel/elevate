package Elevate::YUM;

=encoding utf-8

=head1 NAME

Elevate::YUM

Logic wrapping the 'yum' system binary

=cut

use cPstrict;

use Log::Log4perl qw(:easy);

use Simple::Accessor qw{
  cpev
  pkgmgr
};

sub _build_cpev {
    die q[Missing cpev];
}

sub _build_pkgmgr {
    return '/usr/bin/yum';
}

sub remove ( $self, @pkgs ) {
    return unless scalar @pkgs;

    my $pkgmgr = $self->pkgmgr;

    $self->cpev->ssystem_and_die( $pkgmgr, '-y', 'remove', @pkgs );

    return;
}

sub clean_all ($self) {
    my $pkgmgr = $self->pkgmgr;

    $self->cpev->ssystem( $pkgmgr, 'clean', 'all' );

    return;
}

sub install_rpm_via_url ( $self, $rpm_url ) {
    my $pkgmgr = $self->pkgmgr;

    $self->cpev->ssystem_and_die( $pkgmgr, '-y', 'install', $rpm_url );

    return;
}

sub install ( $self, @pkgs ) {
    return unless scalar @pkgs;

    my $pkgmgr = $self->pkgmgr;

    $self->cpev->ssystem_and_die( $pkgmgr, '-y', 'install', @pkgs );

    return;
}

# No cache here since this is currently only called one time from a blocker
# Consider adding a cache if we ever call it anywhere else
sub get_extra_packages ($self) {
    my $pkgmgr = $self->pkgmgr;

    # From the yum man page
    # yum list extras [glob_exp1] [...]
    #     List the packages installed on the system that are not available
    #     in any yum repository listed in the config file.
    my $out   = $self->cpev->ssystem_hide_and_capture_output( $pkgmgr, 'list', 'extras' );
    my @lines = @{ $out->{stdout} };
    while ( my $line = shift @lines ) {
        last if $line && $line =~ m/^Extra Packages/;
    }

    my @extra_packages;
    while ( my $line = shift @lines ) {
        chomp $line;
        my ( $package, $version, $repo ) = split( qr{\s+}, $line );

        if ( !length $version ) {
            my $extra_line = shift @lines;
            chomp $extra_line;
            $extra_line =~ s/^\s+//;
            ( $version, $repo ) = split( ' ', $extra_line );
        }
        if ( !length $repo ) {
            $repo = shift @lines;
            chomp $repo;
            $repo =~ s/\s+//g;
        }
        length $repo or next;    # We screwed up the parse. move on.

        # We only care about installed packages not associated with repos here
        $repo eq 'installed' or next;

        $package =~ s/\.(noarch|x86_64)$//;
        my $arch = $1 // '?';

        next if $package =~ m/^cpanel-/;
        next if $package =~ m/^kernel/;
        next if $package eq 'filesystem';
        next if $package eq 'basesystem';
        next if $package eq 'virt-what';

        push @extra_packages, { package => $package, version => $version, arch => $arch };
    }

    return @extra_packages;
}

1;
