package Elevate::Components::AbsoluteSymlinks;

=encoding utf-8

=head1 NAME

Elevate::Components::AbsoluteSymlinks

=head2 check

Verify that there are not any absolute symlinks present in /

=head2 pre_distro_upgrade

Update absolute symlinks in / to be relative links

=head2 post_distro_upgrade

noop

=cut

use cPstrict;

use Cpanel::Chdir ();
use Cpanel::UUID  ();
use File::Copy    ();

use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

sub get_abs_symlinks ($self) {
    my %links;
    foreach my $entry ( glob "/*" ) {
        my $path = readlink($entry);    # don't bother with stat, this is fast
        next unless $path && substr( $path, 0, 1 ) eq '/';
        $links{$entry} = $path;
    }
    return %links;
}

sub pre_distro_upgrade ($self) {

    $self->ssystem(qw{/usr/bin/ln -snf usr/local/cpanel/scripts /scripts});
    $self->_absolute_symlinks;

    return;
}

sub _absolute_symlinks ($self) {

    my %links = $self->get_abs_symlinks();
    return unless %links;
    my $chdir = Cpanel::Chdir->new("/");
    foreach my $link ( keys(%links) ) {
        my $updated = substr( $links{$link}, 1 );

        # Now, this has probably .01% of collision chance, but let's get even
        # more paranoid by checking existence and rerolling.
        # Presumably if we can't find something by 10k tries, it just isn't
        # happening no matter how hard we want it.
        my $rand_uid = Cpanel::UUID::random_uuid();
        my $tries    = 0;
        while ( -e "$link-$rand_uid" && $tries++ < 10000 ) {
            $rand_uid = Cpanel::UUID::random_uuid();
        }
        symlink( $updated, "$link-$rand_uid" )     or die "Can't create symlink $link-$rand_uid to $updated: $!";
        File::Copy::mv( "$link-$rand_uid", $link ) or die "Can't overwite $link: $!";
    }
    return;
}

sub check ($self) {
    my %links = $self->get_abs_symlinks();
    WARN( "Symlinks with absolute paths have been found in /:\n\t" . join( ", ", sort keys(%links) ) . "\n" . "This can cause problems during the distro upgrade, so\n" . 'these will be corrected to be relative symlinks before elevation.' ) if %links;
    return;
}

1;
