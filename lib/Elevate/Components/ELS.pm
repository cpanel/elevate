package Elevate::Components::ELS;

=encoding utf-8

=head1 NAME

Elevate::Components::ELS

=head2 check

noop

=head2 pre_distro_upgrade

Remove ELS repo files and ELS specific package

=head2 post_distro_upgrade

Point the alt-common ELS repos at the upgraded distro's major version

=cut

use cPstrict;

use Elevate::OS     ();
use Elevate::PkgMgr ();

use Cpanel::Pkgr  ();
use File::Slurper ();
use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

use constant ELS_PACKAGE => 'els-define';

# These are owned by TuxCare's alt-common-release package.  Unlike the repos
# removed below, they are kept: the alt-* packages they provide remain
# installed after the upgrade and still need an update source.
use constant ALT_COMMON_REPO_FILES => qw{
  /etc/yum.repos.d/alt-common-els.repo
  /etc/yum.repos.d/alt-common-els-rollout.repo
};

sub pre_distro_upgrade ($self) {

    return unless Elevate::OS::remove_els();

    my @files_to_remove = qw{
      /etc/yum.repos.d/centos7-els.repo
      /etc/yum.repos.d/centos7-els-rollout.repo
    };

    foreach my $file (@files_to_remove) {
        if ( -e $file ) {
            unlink $file or WARN("Could not remove file $file: $!");
        }
    }

    Elevate::PkgMgr::remove(ELS_PACKAGE) if Cpanel::Pkgr::is_installed(ELS_PACKAGE);

    return;
}

sub post_distro_upgrade ($self) {

    return unless Elevate::OS::remove_els();

    $self->_update_alt_common_repos();

    return;
}

# TuxCare ships these repo files using $releasever, but the ELS tooling pins
# the baseurls to the original major version.  The distro upgrade leaves that
# pin in place, so dnf keeps offering el7 packages as updates for the el8 ones
# that are installed.  Those el7 packages depend on libraries which no longer
# exist (libreadline.so.6, python), which makes the stage 5 'yum update' fail
# to resolve.  Repoint the baseurls at the major version we upgraded to.
sub _update_alt_common_repos ($self) {

    my $from = Elevate::OS::original_os_major();
    my $to   = Elevate::OS::expected_post_upgrade_major();

    foreach my $file (ALT_COMMON_REPO_FILES) {
        next unless -e $file;

        my $contents = eval { File::Slurper::read_text($file) };
        if ( !defined $contents ) {
            WARN("Could not read $file: $@");
            next;
        }

        my $updated = $contents;
        $updated =~ s{^([ \t]*baseurl[ \t]*=[ \t]*\S*/el/)\Q$from\E(/)}{$1$to$2}gmi;

        if ( $updated eq $contents ) {
            DEBUG("No el$from baseurl found in $file; leaving it unchanged.");
            next;
        }

        eval { File::Slurper::write_text( $file, $updated ); 1 } or do {
            WARN("Could not update $file: $@");
            next;
        };

        INFO("Updated $file to use the el$to repos.");
    }

    return;
}

1;
