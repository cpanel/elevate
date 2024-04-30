package Elevate::Components::EA4;

=encoding utf-8

=head1 NAME

Elevate::Components::EA4

Perform am EA4 backup pre-elevate then restore it after the elevation process.

=cut

use cPstrict;

use Elevate::EA4       ();
use Elevate::StageFile ();

use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

sub pre_leapp ($self) {    # run to perform the backup

    $self->run_once('_backup_ea4_profile');
    $self->run_once('_backup_config_files');
    $self->run_once('_cleanup_rpm_db');

    return;
}

sub post_leapp ($self) {

    $self->run_once('_restore_ea4_profile');
    $self->run_once('_restore_ea_addons');
    $self->run_once('_restore_imunify_phps');

    # This needs to happen last (after EA4 has been reinstalled)
    #
    # On a new install, the RPM behavior for %config is to move the preexisting config file
    # to '.rpmorig' and replace the config file with config file provided by the RPM
    #
    # On a new install, the RPM behavior for %config(noreplace) is to remove the preexisting
    # config file and place the config file provided by the RPM at '.rpmnew'
    #
    # There should not be any need to restart services to pick up the new config files since the last
    # step of stage 5 is to reboot the server so the services will be restarted and pick up the configs
    # after this anyway
    $self->run_once('_restore_config_files');

    return;
}

sub _backup_ea4_profile ($self) {
    Elevate::EA4::backup();
    return;
}

sub _cleanup_rpm_db ($self) {

    # remove all ea- packages
    $self->yum->remove('ea-*');

    return;
}

sub _restore_ea_addons ($self) {

    return unless Elevate::StageFile::read_stage_file('ea4')->{'nginx'};

    INFO("Restoring ea-nginx");

    # ea profile restore it in a broken state - remove & reinstall
    $self->ssystem(qw{/usr/bin/rpm -e --nodeps ea-nginx});
    $self->ssystem_and_die(qw{/usr/bin/yum install -y ea-nginx});

    return;
}

sub _restore_ea4_profile ($self) {

    my $stash      = Elevate::StageFile::read_stage_file();
    my $is_enabled = $stash->{'ea4'} && $stash->{'ea4'}->{'enable'};

    unless ($is_enabled) {
        WARN('Skipping EA4 restore. EA4 does not appear to be enabled on this system.');
        return;
    }

    my $json = $stash->{'ea4'}->{'profile'};
    unless ( length $json && -f $json && -s _ ) {
        WARN('Unable to restore EA4 profile. Is EA4 enabled?');
        INFO("Profile was backed up as: $json") if length $json;
        return;
    }

    $self->ssystem( '/usr/local/bin/ea_install_profile', '--install', $json );

    if ( my $dropped_pkgs = $stash->{'ea4'}->{'dropped_pkgs'} ) {
        if ( scalar keys $dropped_pkgs->%* ) {
            my $msg = qq[One or more EasyApache 4 package(s) cannot be restored from your previous profile:\n];
            foreach my $pkg ( sort keys $dropped_pkgs->%* ) {
                my $type = $dropped_pkgs->{$pkg} // '';
                $msg .= sprintf( "- '%s'%s\n", $pkg, $type eq 'exp' ? ' ( package was Experimental in CentOS 7 )' : '' );
            }
            chomp $msg;
            Elevate::Notify::add_final_notification( $msg, 1 );
        }
    }

    return 1;
}

sub _backup_config_files ($self) {

    Elevate::StageFile::remove_from_stage_file('ea4_config_files');

    my $ea4_regex        = qr/^EA4(:?-c7)?/a;
    my $ea4_config_files = $self->rpm->get_config_files_for_repo($ea4_regex);

    Elevate::StageFile::update_stage_file( { ea4_config_files => $ea4_config_files } );

    return;
}

our %config_files_to_ignore = (
    'ea-nginx' => {
        '/etc/nginx/conf.d/ea-nginx.conf'   => 1,
        '/etc/nginx/ea-nginx/settings.json' => 1,
    },
    'ea-apache24' => {
        '/etc/apache2/conf/httpd.conf' => 1,
    },
);

sub _restore_config_files ($self) {

    my $config_files = Elevate::StageFile::read_stage_file('ea4_config_files');

    foreach my $key ( sort keys %$config_files ) {
        INFO("Restoring config files for package: '$key'");

        my @config_files_to_restore = @{ $config_files->{$key} };
        if ( exists $config_files_to_ignore{$key} ) {
            @config_files_to_restore = grep { !$config_files_to_ignore{$key}{$_} } @config_files_to_restore;
        }

        $self->rpm->restore_config_files(@config_files_to_restore);
    }

    return;
}

sub _restore_imunify_phps ($self) {

    my $php_pkgs = Elevate::StageFile::read_stage_file('ea4_imunify_packages');
    return unless scalar $php_pkgs->@*;

    $self->dnf->install(@$php_pkgs);
    return;
}

1;
