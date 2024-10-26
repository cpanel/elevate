package Elevate::Components::cPanelPlugins;

=encoding utf-8

=head1 NAME

Elevate::Components::cPanelPlugins

=head2 check

noop

=head2 pre_distro_upgrade

Gather list of installed cPanel plugins to reinstall in post

=head2 post_distro_upgrade

Reinstall the list of installed cPanel plugins from pre

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::PkgMgr    ();
use Elevate::StageFile ();

use Cwd           ();
use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

sub pre_distro_upgrade ($self) {

    # Backup arch rpms which we're going to remove and are provided by yum.
    my @installed_arch_cpanel_plugins;

    my $installed    = cpev::yum_list();
    my @cpanel_repos = grep { m/^cpanel-/ } keys %$installed;
    foreach my $repo (@cpanel_repos) {
        push @installed_arch_cpanel_plugins, map { $_->{'package'} } $installed->{$repo}->@*;
    }

    return unless @installed_arch_cpanel_plugins;

    Elevate::StageFile::update_stage_file( { restore => { yum => \@installed_arch_cpanel_plugins } } );

    return;
}

sub post_distro_upgrade ($self) {

    # Restore YUM arch plugins.

    my $stash            = Elevate::StageFile::read_stage_file();
    my $yum_arch_plugins = $stash->{'restore'}->{'yum'} // [];
    return unless scalar @$yum_arch_plugins;

    INFO('Restoring cPanel yum-based-plugins');
    Elevate::PkgMgr::reinstall(@$yum_arch_plugins);

    return;
}

1;
