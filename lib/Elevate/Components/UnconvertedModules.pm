package Elevate::Components::UnconvertedModules;

=encoding utf-8

=head1 NAME

Elevate::Components::UnconvertedModules

=head2 check

noop

=head2 pre_distro_upgrade

noop

=head2 post_distro_upgrade

1. Remove the leapp packages since they do not convert during the leapp upgrade
   and are no longer necessary
2. Warn about other 'el7' modules that are still installed on the system as they
   likely will not work properly after the upgrade

=cut

use cPstrict;

use Elevate::OS     ();
use Elevate::PkgMgr ();

use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

use constant EXEMPTED_PACKAGES => (
    qr/^kernel-/,
    qr/^acronis/,
);

sub post_distro_upgrade ($self) {
    return unless Elevate::OS::needs_leapp();

    $self->run_once('_remove_leapp_packages');
    $self->run_once('_warn_about_other_modules_that_did_not_convert');
    return;
}

sub _remove_leapp_packages ($self) {
    my @leapp_packages = qw{
      elevate-release
      leapp
      leapp-data-almalinux
      leapp-data-cloudlinux
      leapp-deps
      leapp-repository-deps
      leapp-upgrade-el7toel8
      leapp-upgrade-el7toel8-deps
      leapp-upgrade-el8toel9
      leapp-upgrade-el8toel9-deps
      python2-leapp
      python3-leapp
      snactor
    };

    INFO('Removing packages provided by leapp');
    my @to_remove = grep { Cpanel::Pkgr::is_installed($_) } @leapp_packages;
    Elevate::PkgMgr::remove(@to_remove);

    return;
}

sub _warn_about_other_modules_that_did_not_convert ($self) {
    my $installed_packages = Elevate::PkgMgr::get_installed_pkgs();

    my @el_installed_packages;
    foreach my $pkg ( sort keys %$installed_packages ) {
        my $el_package_regex = Elevate::OS::el_package_regex();
        if ( $installed_packages->{$pkg} =~ m/\Q$el_package_regex\E/ ) {
            push @el_installed_packages, "$pkg-$installed_packages->{$pkg}";
        }
    }

    my @el_packages_minus_exemptions;
    foreach my $pkg (@el_installed_packages) {
        next if grep { $pkg =~ m/$_/ } EXEMPTED_PACKAGES();
        push @el_packages_minus_exemptions, $pkg;
    }

    return unless @el_packages_minus_exemptions;

    my $pretty_distro_name = Elevate::OS::upgrade_to_pretty_name();

    my $msg = "The following packages should probably be removed as they will not function on $pretty_distro_name\n\n";
    foreach my $pkg (@el_packages_minus_exemptions) {
        $msg .= "    $pkg\n";
    }

    $msg .= "\nYou can remove these by running: yum -y remove " . join( ' ', @el_packages_minus_exemptions ) . "\n";

    Elevate::Notify::add_final_notification($msg);

    return;
}

1;
