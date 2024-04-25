package Elevate::Blockers::EA4;

=encoding utf-8

=head1 NAME

Elevate::Blockers::EA4

Blocker to check EasyApache profile compatibility.

=cut

use cPstrict;

use Elevate::EA4       ();
use Elevate::StageFile ();

use Cpanel::JSON            ();
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

    my $pretty_distro_name = $self->upgrade_to_pretty_name();

    INFO("Checking EasyApache profile compatibility with $pretty_distro_name.");

    Elevate::EA4::backup();

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
    my $current_php_usage = $self->_get_php_versions_in_use();

    # Always return true if the api call failed
    return 1 if $current_php_usage->{api_fail};

    return $current_php_usage->{$php} ? 1 : 0;
}

my $php_versions_in_use;

sub _get_php_versions_in_use ($self) {
    return $php_versions_in_use if defined $php_versions_in_use && ref $php_versions_in_use eq 'HASH';

    my $out    = Cpanel::SafeRun::Simple::saferunnoerror(qw{/usr/local/cpanel/bin/whmapi1 --output=json php_get_vhost_versions});
    my $result = eval { Cpanel::JSON::Load($out); } // {};

    unless ( $result->{metadata}{result} ) {

        WARN( <<~"EOS" );
        Unable to determine if PHP versions that will be dropped are in use by
        a domain.  Assuming that they are in use and blocking to be safe.

        EOS

        $php_versions_in_use->{api_fail} = 1;
        return $php_versions_in_use;
    }

    foreach my $domain_info ( @{ $result->{data}{versions} } ) {
        my $php_version = $domain_info->{version};
        $php_versions_in_use->{$php_version} = 1;
    }

    return $php_versions_in_use;
}

1;
