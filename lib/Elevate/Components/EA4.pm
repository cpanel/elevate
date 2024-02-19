package Elevate::Components::EA4;

=encoding utf-8

=head1 NAME

Elevate::Components::EA4

Perform am EA4 backup pre-elevate then restore it after the elevation process.

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::OS        ();
use Elevate::RPM       ();
use Elevate::YUM       ();

use Cwd           ();
use Log::Log4perl qw(:easy);

use Cpanel::JSON            ();
use Cpanel::Pkgr            ();
use Cpanel::SafeRun::Simple ();

use parent qw{Elevate::Components::Base};

use Elevate::Blockers ();

##
## Call early so we can use a blocker based on existing ea4 profile
##

# note: the backup process is triggered by Elevate::Blockers::EA4
sub backup ($self) {    # run by the check (should be a dry run mode)

    $self->_backup_ea4_profile;
    $self->_backup_ea_addons;

    return;
}

sub pre_leapp ($self) {    # run to perform the backup

    $self->run_once('_backup_ea4_profile');
    $self->run_once('_backup_ea_addons');
    $self->run_once('_backup_config_files');
    $self->run_once('_cleanup_rpm_db');

    return;
}

sub post_leapp ($self) {

    $self->run_once('_restore_ea4_profile');
    $self->run_once('_restore_ea_addons');

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

sub _cleanup_rpm_db ($self) {

    # remove all ea- packages
    $self->yum->remove('ea-*');

    return;
}

sub _restore_ea_addons ($self) {

    return unless cpev::read_stage_file('ea4')->{'nginx'};

    INFO("Restoring ea-nginx");

    # ea profile restore it in a broken state - remove & reinstall
    $self->ssystem(qw{/usr/bin/rpm -e --nodeps ea-nginx});
    $self->ssystem_and_die(qw{/usr/bin/yum install -y ea-nginx});

    return;
}

sub _backup_ea_addons ($self) {

    if ( Cpanel::Pkgr::is_installed('ea-nginx') ) {
        cpev::update_stage_file( { ea4 => { nginx => 1 } } );
    }
    else {
        cpev::update_stage_file( { ea4 => { nginx => 0 } } );
    }

    return;
}

sub _backup_ea4_profile ($self) {    ## _backup_ea4_profile

    my $use_ea4 = Cpanel::Config::Httpd::is_ea4() ? 1 : 0;

    cpev::remove_from_stage_file('ea4');
    cpev::update_stage_file( { ea4 => { enable => $use_ea4 } } );

    unless ($use_ea4) {

        WARN('Skipping EA4 backup. EA4 does not appear to be enabled on this system');

        return;
    }

    my $json_path = $self->_get_ea4_profile();

    my $data = { profile => $json_path };

    # store dropped packages
    my $profile = eval { Cpanel::JSON::LoadFile($json_path) } // {};
    if ( ref $profile->{os_upgrade} && ref $profile->{os_upgrade}->{dropped_pkgs} ) {
        $data->{dropped_pkgs} = $profile->{os_upgrade}->{dropped_pkgs};
    }

    cpev::update_stage_file( { ea4 => $data } );    # FIXME

    return 1;
}

sub _get_ea4_profile ($self) {

    my $ea_alias = Elevate::OS::ea_alias();

    my @cmd = ( '/usr/local/bin/ea_current_to_profile', "--target-os=$ea_alias" );

    my $profile_file;

    if ( Elevate::Blockers->is_check_mode() ) {

        # use a temporary file in check mode
        $profile_file = $self->tmp_dir() . '/ea_profile.json';
        push @cmd, "--output=$profile_file";
    }

    my $cmd_str = join( ' ', @cmd );

    INFO("Running: $cmd_str");
    my $output = Cpanel::SafeRun::Simple::saferunnoerror(@cmd) // '';
    die qq[Unable to backup EA4 profile. Failure from $cmd_str] if $?;

    if ( !$profile_file ) {

        # parse the output to find the profile file...

        my @lines = split( "\n", $output );

        if ( scalar @lines == 1 ) {
            $profile_file = $lines[0];
        }
        else {
            foreach my $l ( reverse @lines ) {
                next unless $l =~ m{^/.*\.json};
                if ( -f $l ) {
                    $profile_file = $l;
                    last;
                }
            }
        }
    }

    die "Unable to backup EA4 profile running: $cmd_str" unless length $profile_file && -f $profile_file && -s _;
    INFO("Backed up EA4 profile to $profile_file");

    return $profile_file;
}

sub _restore_ea4_profile ($self) {

    my $stash      = cpev::read_stage_file();
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

    cpev::remove_from_stage_file('ea4_config_files');

    my $ea4_regex        = qr/^EA4(:?-c7)?/a;
    my $ea4_config_files = $self->rpm->get_config_files_for_repo($ea4_regex);

    cpev::update_stage_file( { ea4_config_files => $ea4_config_files } );

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

    my $config_files = cpev::read_stage_file('ea4_config_files');

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

1;
