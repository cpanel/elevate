package Elevate::OS::CentOS7;

=encoding utf-8

=head1 NAME

Elevate::OS::CentOS7 - CentOS7 custom values

=cut

use cPstrict;

use Log::Log4perl qw(:easy);

use parent 'Elevate::OS::Base';

sub _build_elevate_rpm_url ($self) {
    return 'https://repo.almalinux.org/elevate/elevate-release-latest-el7.noarch.rpm';
}

sub _build_default_upgrade_to ($self) {
    return 'almalinux';
}

sub _build_leapp_data_pkg ($self) {
    my $upgrade_to = $self->upgrade_to();
    return $upgrade_to =~ m/^rocky/ai ? 'leapp-data-rocky' : 'leapp-data-almalinux';
}

sub _build_name ($self) {
    return 'CentOS7';
}

sub _build_pretty_name ($self) {
    return 'CentOS 7';
}

1;
