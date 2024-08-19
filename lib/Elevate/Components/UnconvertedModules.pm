package Elevate::Components::UnconvertedModules;

=encoding utf-8

=head1 NAME

Elevate::Components::UnconvertedModules

Remove the leapp packages since they do not convert during the leapp upgrade and
are no longer necessary

Warn about other 'el7' modules that are still installed on the system as they
likely will not work properly after the upgrade

=cut

use cPstrict;

use Elevate::OS ();

use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

sub pre_leapp ($self) {
    return;
}

sub post_leapp ($self) {
    $self->run_once('_remove_leapp_packages');
    $self->run_once('_warn_about_other_modules_that_did_not_convert');
    $self->run_once('_purge_packages');
    return;
}

sub _remove_leapp_packages ($self) {
    return unless Elevate::OS::needs_leapp();

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
    return if Elevate::OS::is_apt_based();

    my @installed_packages                    = $self->rpm->get_installed_rpms();
    my @el7_installed_packages                = grep { $_ =~ m/el7/ } @installed_packages;
    my @exclude_kernel_el7_installed_packages = grep { $_ !~ m/^kernel-/ } @el7_installed_packages;

    return unless @exclude_kernel_el7_installed_packages;

    my $pretty_distro_name = Elevate::OS::upgrade_to_pretty_name();

    my $msg = "The following packages should probably be removed as they will not function on $pretty_distro_name\n\n";
    foreach my $pkg (@exclude_kernel_el7_installed_packages) {
        $msg .= "    $pkg\n";
    }

    $msg .= "\nYou can remove these by running: yum -y remove " . join( ' ', @exclude_kernel_el7_installed_packages ) . "\n";

    Elevate::Notify::add_final_notification($msg);

    return;
}

sub _purge_packages ($self) {
    return unless Elevate::OS::is_apt_based();

    INFO('Purging packages that are no longer needed after upgrade');
    $self->apt->autoremove_post_upgrade();

    return;
}

1;
