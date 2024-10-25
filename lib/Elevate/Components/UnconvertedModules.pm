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

use Elevate::OS         ();
use Elevate::PkgUtility ();

use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

use constant EXEMPTED_PACKAGES => (
    qr/^kernel-/,
    qr/^acronis/,
);

sub post_distro_upgrade ($self) {
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
      python2-leapp
    };

    INFO('Removing packages provided by leapp');
    my @to_remove = grep { Cpanel::Pkgr::is_installed($_) } @leapp_packages;
    $self->dnf->remove(@to_remove);

    return;
}

sub _warn_about_other_modules_that_did_not_convert ($self) {
    my @installed_packages     = Elevate::PkgUtility::get_installed_rpms();
    my @el7_installed_packages = grep { $_ =~ m/el7/ } @installed_packages;

    my @el7_packages_minus_exemptions;
    foreach my $pkg (@el7_installed_packages) {
        next if grep { $pkg =~ m/$_/ } EXEMPTED_PACKAGES();
        push @el7_packages_minus_exemptions, $pkg;
    }

    return unless @el7_packages_minus_exemptions;

    my $pretty_distro_name = Elevate::OS::upgrade_to_pretty_name();

    my $msg = "The following packages should probably be removed as they will not function on $pretty_distro_name\n\n";
    foreach my $pkg (@el7_packages_minus_exemptions) {
        $msg .= "    $pkg\n";
    }

    $msg .= "\nYou can remove these by running: yum -y remove " . join( ' ', @el7_packages_minus_exemptions ) . "\n";

    Elevate::Notify::add_final_notification($msg);

    return;
}

1;
