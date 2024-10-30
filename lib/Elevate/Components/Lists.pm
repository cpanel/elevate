package Elevate::Components::Lists;

=encoding utf-8

=head1 NAME

Elevate::Components::Lists

=head2 check

1. Verify that apt is stable
2. Verify that apt does not have any held packages as that can cause the upgrade to fail
3. Determine if there are invalid/unvetted lists being used

=head2 pre_distro_upgrade

noop

=head2 post_distro_upgrade

Update the vetted list files for Ubuntu 22.04

=cut

use cPstrict;

use Elevate::OS     ();
use Elevate::PkgMgr ();

use File::Slurper ();

use parent qw{Elevate::Components::Base};

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

    my $error_msg = <<~'EOS';
    '/usr/bin/apt' failed to return cleanly. This could be due to a temporary
    mirror problem, or it could indicate a larger issue, such as a broken
    list. Since this script relies heavily on apt, you will need to address this
    issue before upgrading.

    If you need assistance, open a ticket with cPanel Support, as outlined here:

    https://docs.cpanel.net/knowledge-base/technical-support-services/how-to-open-a-technical-support-ticket/
    EOS

    my $ret = Elevate::PkgMgr::clean_all();
    if ( $ret->{status} != 0 ) {
        WARN( "Errors encountered running 'apt-get clean': " . $ret->{stderr} );
    }

    my $makecache = Elevate::PkgMgr::makecache();
    if ( $makecache =~ m/\S/ms ) {
        ERROR($error_msg);
        ERROR($makecache);
        my $id = ref($self) . '::AptUpdateError';
        return $self->has_blocker(
            $error_msg . $makecache,
            info => {
                name  => $id,
                error => $makecache,
            },
            blocker_id => $id,
            quiet      => 1,
        );
    }

    return;
}

sub _blocker_apt_has_held_packages ($self) {
    my $out = Elevate::PkgMgr::showhold();

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
        return $self->has_blocker( <<~"EOS" );
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
        return $self->has_blocker( <<~"EOS" );
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

sub post_distro_upgrade ($self) {
    return unless Elevate::OS::is_apt_based();

    $self->run_once('update_list_files');
    return;
}

sub update_list_files ($self) {
    my $list_dir = APT_LIST_D;

    opendir( my $dh, $list_dir ) or die "Unable to read directory $list_dir: $!\n";
    foreach my $list_file ( readdir($dh) ) {
        next unless $list_file =~ m{\.list$};
        $self->_update_list_file($list_file);
    }

    return;
}

sub _update_list_file ( $self, $list_file ) {
    my $list_dir         = APT_LIST_D;
    my $vetted_apt_lists = Elevate::OS::vetted_apt_lists();

    # No use making this fatal since we block on it
    unless ( $vetted_apt_lists->{$list_file} ) {
        WARN("Unknown list file: $list_dir/$list_file\n");
        return;
    }

    File::Slurper::write_binary( "$list_dir/$list_file", "$vetted_apt_lists->{$list_file}\n" );

    return;
}

1;
