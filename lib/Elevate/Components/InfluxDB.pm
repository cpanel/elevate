package Elevate::Components::InfluxDB;

=encoding utf-8

=head1 NAME

Elevate::Components::InfluxDB

Capture and reinstall InfluxDB packages.

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::StageFile ();

use Cpanel::Pkgr  ();
use Cwd           ();
use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

sub pre_distro_upgrade ($self) {

    Elevate::StageFile::remove_from_stage_file('reinstall.influxdb');

    return unless Cpanel::Pkgr::is_installed('telegraf');

    INFO("Not removing influxdb. Will re-install it after elevate.");
    Elevate::StageFile::update_stage_file( { 'reinstall' => { 'influxdb' => 1 } } );

    return;
}

sub post_distro_upgrade ($self) {

    return unless Elevate::StageFile::read_stage_file('reinstall')->{'influxdb'};

    INFO("Re-installing telegraf for influxdb");
    $self->ssystem_and_die(qw{/usr/bin/yum -y reinstall telegraf});

    return;
}

1;
