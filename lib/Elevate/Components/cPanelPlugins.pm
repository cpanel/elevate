package Elevate::Components::cPanelPlugins;

=encoding utf-8

=head1 NAME

Elevate::Components::cPanelPlugins

Remove and reinstall some arch RPMs. (plugins)

=cut

use cPstrict;

use Elevate::Constants ();
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
    $self->ssystem( qw{ /usr/bin/dnf -y reinstall }, @$yum_arch_plugins );

    return;
}

1;
