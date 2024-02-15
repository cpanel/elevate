package Elevate::OS::CentOS7;

=encoding utf-8

=head1 NAME

Elevate::OS::CentOS7 - CentOS7 custom values

=cut

use cPstrict;

use Log::Log4perl qw(:easy);

use parent 'Elevate::OS::RHEL';

use constant available_upgrade_paths => (
    'alma',
    'almalinux',
    'rocky',
    'rockylinux',
);

use constant default_upgrade_to => 'AlmaLinux';
use constant ea_alias           => 'CentOS_8';
use constant elevate_rpm_url    => 'https://repo.almalinux.org/elevate/elevate-release-latest-el7.noarch.rpm';
use constant name               => 'CentOS7';
use constant pretty_name        => 'CentOS 7';

sub leapp_data_pkg () {
    my $upgrade_to = Elevate::OS::upgrade_to();
    return $upgrade_to =~ m/^rocky/ai ? 'leapp-data-rocky' : 'leapp-data-almalinux';
}

1;
