package Elevate::Blockers::EA4;

=encoding utf-8

=head1 NAME

Elevate::Blockers::EA4

Blocker to check EasyApache profile compatibility.

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::EA4       ();
use Elevate::OS        ();
use Elevate::StageFile ();

use Cpanel::JSON            ();
use Cpanel::Pkgr            ();
use Cpanel::SafeRun::Simple ();

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

    my $pretty_distro_name = Elevate::OS::upgrade_to_pretty_name();

    INFO("Checking EasyApache profile compatibility with $pretty_distro_name.");

    my $check_mode = $self->is_check_mode();
    Elevate::EA4::backup($check_mode);

    my @incompatible_packages = $self->_get_incompatible_packages();

    return unless @incompatible_packages;

    my $list = join( "\n", map { "- $_" } @incompatible_packages );

    return $self->has_blocker( <<~"EOS" );
    One or more EasyApache 4 package(s) are not compatible with $pretty_distro_name.
    Please remove these packages before continuing the update.
    $list
    EOS
}

sub _get_incompatible_packages ($self) {

    my $stash        = Elevate::StageFile::read_stage_file();
    my $dropped_pkgs = $stash->{'ea4'}->{'dropped_pkgs'} // {};
    return unless scalar keys $dropped_pkgs->%*;

    my @incompatible;
    foreach my $pkg ( sort keys %$dropped_pkgs ) {
        my $type = $dropped_pkgs->{$pkg} // '';
        next if $type eq 'exp';                          # use of experimental packages is a non blocker
        next if $pkg =~ m/^ea-openssl(?:11)?-devel$/;    # ignore these packages, as they can be orphans

        if ( $pkg =~ m/^(ea-php[0-9]+)/ ) {
            my $php_pkg = $1;
            next unless $self->_php_version_is_in_use($php_pkg);

        }
        push @incompatible, $pkg;
    }

    return @incompatible;
}

sub _php_version_is_in_use ( $self, $php ) {
    my $current_php_usage = $self->_get_php_usage();

    # Always return true if the api call failed
    return 1 if $current_php_usage->{api_fail};

    return $current_php_usage->{$php} ? 1 : 0;
}

our $php_usage;

sub _get_php_usage ($self) {
    return $php_usage if defined $php_usage && ref $php_usage eq 'HASH';

    my $php_get_vhost_versions = Elevate::EA4::php_get_vhost_versions();
    if ( !defined $php_get_vhost_versions ) {
        $php_usage->{api_fail} = 1;
        return $php_usage;
    }

    foreach my $domain_info (@$php_get_vhost_versions) {
        my $php_version = $domain_info->{version};
        $php_usage->{$php_version} = 1;
    }

    return $php_usage;
}

1;
