package Elevate::OS::CentOS7;

=encoding utf-8

=head1 NAME

Elevate::OS::CentOS7 - CentOS7 custom values

=cut

use cPstrict;

use Log::Log4perl qw(:easy);

use parent 'Elevate::OS::RHEL';

use constant default_upgrade_to => 'AlmaLinux';
use constant ea_alias           => 'CentOS_8';
use constant elevate_rpm_url    => 'https://repo.almalinux.org/elevate/elevate-release-latest-el7.noarch.rpm';
use constant leapp_data_pkg     => 'leapp-data-almalinux';
use constant leapp_repo_prod    => 'elevate';
use constant name               => 'CentOS7';
use constant pretty_name        => 'CentOS 7';
use constant remove_els         => 1;

sub vetted_yum_repo ($self) {

    my @repos = $self->SUPER::vetted_yum_repo();

    # A component uninstalls this repo on CentOS 7, no need to block on it
    push @repos, qr/centos7[-]*els(-rollout-[0-9]+|)/;
    return @repos;
}

1;
