package Elevate::Blockers::Lists;

=encoding utf-8

=head1 NAME

Elevate::Blockers::Lists

Blocker to check if the Apt lists are compliant with the elevate process.

=cut

use cPstrict;

use Elevate::OS ();

use parent qw{Elevate::Blockers::Base};

use Log::Log4perl qw(:easy);

use constant APT_LIST_D => q[/etc/apt/sources.list.d];

sub check ($self) {
    my $ok = 1;

    return $ok unless Elevate::OS::is_apt_based();

    $ok = 0 if $self->_blocker_apt_can_update();
    $ok = 0 if $self->_blocker_apt_has_held_packages();
    $ok = 0 if $self->_blocker_invalid_apt_lists();

    return $ok;
}

sub _blocker_apt_can_update ($self) {

    eval { $self->apt->update(); 1; } or do {

        $self->has_blocker( <<~'EOS' );
        '/usr/bin/apt update' failed to return cleanly.  This could be due to
        a temporary mirror problem or it could indicate a larger issue, such as
        a broken list.  Since this script relies heavily on apt, you will need
        to address this issue before upgrading.

        If you need assistance, open a ticket with cPanel support, as outlined here:

        https://docs.cpanel.net/knowledge-base/technical-support-services/how-to-open-a-technical-support-ticket/
        EOS

    };

    return;
}

sub _blocker_apt_has_held_packages ($self) {
    my $out = $self->apt->showhold();

    if ( $out->{status} != 0 ) {

        my $stderr = join( "\n", @{ $out->{stderr} } );
        return $self->has_blocker( <<~"EOS" );
        '/usr/bin/apt-mark showhold' failed to return cleanly:

        $stderr

        Since we are unable to reliably determine if any packages are being held back,
        you will need to address this issue before upgrading.

        If you need assistance, open a ticket with cPanel support, as outlined here:

        https://docs.cpanel.net/knowledge-base/technical-support-services/how-to-open-a-technical-support-ticket/
        EOS
    }

    my @held_packages = @{ $out->{stdout} };
    if (@held_packages) {

        my $held_pkgs = join( "\n", @held_packages );
        my $pkgs      = join( ' ',  @held_packages );
        $self->has_blocker( <<~"EOS" );
        The following packages are currently held back and could prevent the
        upgrade from succeeding:

        $held_pkgs

        To unhold the packages, execute

        /usr/bin/apt-mark unhold $pkgs

        EOS
    }

    return;
}

sub _blocker_invalid_apt_lists ($self) {

    my @unvetted_list_files;

    my $list_dir         = APT_LIST_D;
    my $vetted_apt_lists = Elevate::OS::vetted_apt_lists();
    opendir( my $dh, $list_dir ) or die "Unable to read directory $list_dir: $!\n";
    foreach my $list_file ( readdir($dh) ) {
        next unless $list_file =~ m{\.list$};
        next if exists $vetted_apt_lists->{$list_file};
        push @unvetted_list_files, $list_file;
    }

    if (@unvetted_list_files) {

        my $list_files = join( "\n", @unvetted_list_files );
        $self->has_blocker( <<~"EOS" );
        The following unsupported list files were found in $list_dir:

        $list_files

        You can temporarily disable these lists by renaming them.  For example,
        to rename a list file titled sample.list, you would do the following:

        mv $list_dir/sample.list $list_dir/sample.list.disabled

        Then, to reenable this list, you would simply rename the file back
        to the original '.list' suffix.
        EOS
    }

    return;
}

1;
