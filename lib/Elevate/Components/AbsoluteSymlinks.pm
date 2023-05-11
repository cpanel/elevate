package Elevate::Components::AbsoluteSymlinks;

=encoding utf-8

=head1 NAME

Elevate::Components::AbsoluteSymlinks

Alter absolute symlinks in / to be relative links

=cut

use cPstrict;

use Cpanel::Chdir ();
use Cpanel::UUID  ();
use File::Copy    ();

use parent qw{Elevate::Components::Base};

sub get_abs_symlinks {
    my %links;
    foreach my $entry (glob "/*") {
        my $path = readlink($entry); # don't bother with stat, this is fast
        next unless $path && substr( $path, 0, 1 ) eq '/';
        $links{$entry} = $path;
    }
    return %links;
}

sub pre_leapp {
    my %links = get_abs_symlinks();
    return unless %links;
    my $chdir = Cpanel::Chdir->new("/");
    foreach my $link (keys(%links)) {
        my $updated = substr( $links{$link}, 1 );

        my $rand_uid = Cpanel::UUID::random_uuid();
        symlink( $updated, "$link-$rand_uid" ) or die "Can't create symlink $link-$rand_uid to $updated: $!";
        File::Copy::move( "$link-$rand_uid", $link ) or die "Can't overwite $link: $!";
    }
    return;
}

sub post_leapp {
    return;
}

1;
