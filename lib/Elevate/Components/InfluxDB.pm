package Elevate::Components::InfluxDB;

=encoding utf-8

=head1 NAME

Elevate::Components::InfluxDB

=head2 check

noop

=head2 pre_distro_upgrade

Capture that influxdb is installed

=head2 post_distro_upgrade

Reinstall influxdb if it was installed

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::PkgMgr    ();
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
    Elevate::PkgMgr::reinstall('telegraf');

    return;
}

1;
