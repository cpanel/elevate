package Elevate::Components::EA4;

=encoding utf-8

=head1 NAME

Elevate::Components::EA4

=head2 check

Verify if any installed EA4 packages are incompatible with the upgrade

=head2 pre_distro_upgrade

Remove EA4

=head2 post_distro_upgrade

1. Reinstall EA4
2. Restore EA4 config files
3. Update sites to use correct PHP versions

=head2 pre_imunify

1. Gather PHP usage
2. Backup EA4 profile
3. Backup config files

TODO: Split pre_imunify out to its own component

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::EA4       ();
use Elevate::OS        ();
use Elevate::PkgMgr    ();
use Elevate::StageFile ();

use Cpanel::JSON            ();
use Cpanel::Pkgr            ();
use Cpanel::SafeRun::Simple ();

use Cwd           ();
use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

sub pre_imunify ($self) {
    $self->run_once('_gather_php_usage');
    $self->run_once('_backup_ea4_profile');
    $self->run_once('_backup_config_files');
    return;
}

sub pre_distro_upgrade ($self) {
    $self->run_once('_cleanup_rpm_db');
    return;
}

sub post_distro_upgrade ($self) {

    $self->run_once('_restore_ea4_profile');
    $self->run_once('_restore_ea_addons');

    # This needs to happen after EA4 has been reinstalled
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

    $self->run_once('_ensure_sites_use_correct_php_version');

    return;
}

sub _backup_ea4_profile ($self) {
    Elevate::EA4::backup();
    return;
}

sub _cleanup_rpm_db ($self) {

    # remove all ea- packages
    Elevate::PkgMgr::remove('ea-*');

    return;
}

sub _restore_ea_addons ($self) {

    return unless Elevate::StageFile::read_stage_file('ea4')->{'nginx'};

    INFO("Restoring ea-nginx");

    # ea profile restore it in a broken state - remove & reinstall
    Elevate::PkgMgr::remove_no_dependencies('ea-nginx');
    Elevate::PkgMgr::install('ea-nginx');

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

    my $ea4_config_files = Elevate::PkgMgr::get_config_files_for_pkg_prefix('ea-');

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

        Elevate::PkgMgr::restore_config_files(@config_files_to_restore);
    }

    return;
}

sub _ensure_sites_use_correct_php_version ($self) {

    my $vhost_versions = Elevate::StageFile::read_stage_file('php_get_vhost_versions');
    return unless ref $vhost_versions eq 'ARRAY';
    return unless scalar $vhost_versions->@*;

    foreach my $vhost_entry (@$vhost_versions) {
        my $version = $vhost_entry->{version};
        my $vhost   = $vhost_entry->{vhost};
        my $fpm     = $vhost_entry->{php_fpm};

        my @api_cmd = (
            '/usr/local/cpanel/bin/whmapi1',
            '--output=json',
            'php_set_vhost_versions',
            "version=$version",
            "vhost=$vhost",
            "php_fpm=$fpm",
        );

        my $out    = Cpanel::SafeRun::Simple::saferunnoerror(@api_cmd);
        my $result = eval { Cpanel::JSON::Load($out); } // {};

        my $api_string = join( ' ', @api_cmd );
        unless ( $result->{metadata}{result} ) {

            WARN( <<~"EOS" );
            Unable to set $vhost back to its desired PHP version.  This site may
            be using the incorrect version of PHP.  To set it back to its
            original PHP version, execute the following command:

            $api_string
            EOS
        }
    }

    return;
}

sub _gather_php_usage ($self) {
    my $php_get_vhost_versions = Elevate::EA4::php_get_vhost_versions();
    Elevate::StageFile::remove_from_stage_file('php_get_vhost_versions');
    Elevate::StageFile::update_stage_file( { php_get_vhost_versions => $php_get_vhost_versions } );
    return;
}

sub check ($self) {

    return $self->_blocker_ea4_profile;
}

#
# _blocker_ea4_profile: perform an early ea4 profile backup
#   and check for incompatible packages.
#
sub _blocker_ea4_profile ($self) {

    # perform an early backup so we can check the list of dropped packages

    my $pretty_distro_name = Elevate::OS::upgrade_to_pretty_name();

    INFO("Checking EasyApache profile compatibility with $pretty_distro_name.");

    my $check_mode = $self->is_check_mode();
    Elevate::EA4::backup($check_mode);

    my @incompatible_packages = $self->_get_incompatible_packages();

    return unless @incompatible_packages;

    my $list = join( "\n", map { "- $_" } @incompatible_packages );

    return $self->has_blocker( <<~"EOS" );
    One or more EasyApache 4 package(s) are not compatible with $pretty_distro_name.
    Please remove these packages before continuing the update.
    $list
    EOS
}

sub _get_incompatible_packages ($self) {

    my $stash        = Elevate::StageFile::read_stage_file();
    my $dropped_pkgs = $stash->{'ea4'}->{'dropped_pkgs'} // {};
    return unless scalar keys $dropped_pkgs->%*;

    my @incompatible;
    foreach my $pkg ( sort keys %$dropped_pkgs ) {
        my $type = $dropped_pkgs->{$pkg} // '';
        next if $type eq 'exp';                          # use of experimental packages is a non blocker
        next if $pkg =~ m/^ea-openssl(?:11)?-devel$/;    # ignore these packages, as they can be orphans

        if ( $pkg =~ m/^(ea-php[0-9]+)/ ) {
            my $php_pkg = $1;
            next unless $self->_php_version_is_in_use($php_pkg);

        }
        push @incompatible, $pkg;
    }

    return @incompatible;
}

sub _php_version_is_in_use ( $self, $php ) {
    my $current_php_usage = $self->_get_php_usage();

    # Always return true if the api call failed
    return 1 if $current_php_usage->{api_fail};

    return $current_php_usage->{$php} ? 1 : 0;
}

our $php_usage;

sub _get_php_usage ($self) {
    return $php_usage if defined $php_usage && ref $php_usage eq 'HASH';

    my $php_get_vhost_versions = Elevate::EA4::php_get_vhost_versions();
    if ( !defined $php_get_vhost_versions ) {
        $php_usage->{api_fail} = 1;
        return $php_usage;
    }

    foreach my $domain_info (@$php_get_vhost_versions) {
        my $php_version = $domain_info->{version};
        $php_usage->{$php_version} = 1;
    }

    return $php_usage;
}

1;
