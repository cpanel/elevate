package Elevate::Blockers::EA4;

=encoding utf-8

=head1 NAME

Elevate::Blockers::EA4

Blocker to check EasyApache profile compatibility.

=cut

use cPstrict;

use Elevate::Constants ();

use parent qw{Elevate::Blockers::Base};

use Cwd           ();
use Log::Log4perl qw(:easy);

use Cpanel::JSON ();

sub check ($self) {

    return $self->_blocker_ea4_profile;
}

#
# _blocker_ea4_profile: perform an early ea4 profile backup
#   and check for incompatible packages.
#
sub _blocker_ea4_profile ($self) {

    # perform an early backup so we can check the list of dropped packages

    my $pretty_distro_name = $self->upgrade_to_pretty_name();
    INFO("Checking EasyApache profile compatibility with $pretty_distro_name.");

    $self->cpev->component('EA4')->backup;                        # _backup_ea4_profile();
    my $stash        = cpev::read_stage_file();                   # FIXME - move it to a function
    my $dropped_pkgs = $stash->{'ea4'}->{'dropped_pkgs'} // {};
    return unless scalar keys $dropped_pkgs->%*;

    my @incompatible_packages;
    foreach my $pkg ( sort keys $dropped_pkgs->%* ) {
        my $type = $dropped_pkgs->{$pkg} // '';
        next if $type eq 'exp';                          # use of experimental packages is a non blocker
        next if $pkg =~ m/^ea-openssl(?:11)?-devel$/;    # ignore these packages, as they can be orphans
        push @incompatible_packages, $pkg;
    }

    return unless @incompatible_packages;

    my $list = join( "\n", map { "- $_" } @incompatible_packages );

    return $self->has_blocker( <<~"EOS" );
    One or more EasyApache 4 package(s) are not compatible with $pretty_distro_name.
    Please remove these packages before continuing the update.
    $list
    EOS
}

1;
