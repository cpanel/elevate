package Elevate::Components::EA4;

=encoding utf-8

=head1 NAME

Elevate::Components::EA4

=head2 check

Verify if any installed EA4 packages are incompatible with the upgrade

=head2 pre_imunify

1. Gather PHP usage
2. Backup EA4 profile
3. Backup config files

=head2 pre_distro_upgrade

1. Snapshot user PHP Selector settings
2. Snapshot PHP-FPM services
3. Remove EA4

=head2 post_distro_upgrade

1. Reinstall EA4
2. Restore EA4 config files
3. Restore user PHP Selector settings
4. Restore PHP-FPM services
5. Update sites to use correct PHP versions

TODO: Split pre_imunify out to its own component

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::EA4       ();
use Elevate::OS        ();
use Elevate::PkgMgr    ();
use Elevate::StageFile ();

use Cpanel::Config::Users   ();
use Cpanel::EA4::Install    ();
use Cpanel::JSON            ();
use Cpanel::PackMan         ();
use Cpanel::Pkgr            ();
use Cpanel::PwCache         ();
use Cpanel::SafeRun::Object ();
use Cpanel::SafeRun::Simple ();

use Path::Tiny ();

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
    $self->run_once('_snapshot_user_php_selectors');
    $self->run_once('_snapshot_php_fpm_services');
    $self->run_once('_cleanup_rpm_db');
    $self->_remove_ea4_repo();
    return;
}

sub post_distro_upgrade ($self) {

    $self->run_once('_restore_ea4_profile');
    $self->run_once('_restore_ea_addons');
    $self->run_once('_restore_user_php_selectors');
    $self->run_once('_restore_php_fpm_services');

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

    my @ea_pkgs = sort keys %{ Elevate::PkgMgr::get_installed_pkgs('ea-*') };
    Elevate::StageFile::update_stage_file( { 'ea_prefix_packages_to_restore' => \@ea_pkgs } ) if @ea_pkgs;

    # remove all ea- packages
    Elevate::PkgMgr::remove('ea-*');

    # Remove any additional packages included in EA4 now that this is supported
    # Only do this if additional prefix packages have been added
    if ( $self->_has_non_ea_prefix_packages() ) {
        my @supported_non_ea_prefix_packages = $self->_get_installed_non_ea_prefix_supported_packages();
        Elevate::PkgMgr::remove(@supported_non_ea_prefix_packages);
    }

    return;
}

sub _snapshot_user_php_selectors ($self) {

    # Short-circuit if the existing system doesn't have the ability to change the PHP Selector:
    return unless -x '/usr/sbin/cloudlinux-selector';

    my %homedirs = map { $_ => Cpanel::PwCache::gethomedir($_) } Cpanel::Config::Users::getcpusers();

    # Capture each user's PHP Selector version before _cleanup_rpm_db. The
    # alt-php* %postun scriptlet resets every CageFS user's choice to native
    # when alt-php is fully uninstalled (CLOS-4301); package reinstallation
    # does not restore the version, so we replay it ourselves in stage 4.
    my %user_versions;
    for my $user ( keys %homedirs ) {
        my $path = "$homedirs{$user}/.cl.selector/defaults.cfg";
        open my $fh, '<', $path or next;
        my $in_versions = 0;
        while ( my $line = <$fh> ) {
            if ( $line =~ /^\s*\[(\S+)\]\s*$/ ) {
                $in_versions = ( $1 eq 'versions' ) ? 1 : 0;
                next;
            }
            next unless $in_versions;
            if ( $line =~ /^\s*php\s*=\s*(\S+)\s*$/ ) {
                my $version = $1;
                $user_versions{$user} = $version if $version ne 'native';
                last;    # Unwritten assumption: the first encounter with a php setting in a [versions] section is the one that matters, rather than the last one.
            }
        }
        close $fh;
    }

    return unless scalar keys %user_versions;

    INFO( sprintf( 'Recorded %d user(s) with non-native PHP Selector versions.', scalar keys %user_versions ) );
    Elevate::StageFile::update_stage_file( { 'user_php_selectors' => \%user_versions } );
    return;
}

sub _restore_user_php_selectors ($self) {

    # Replay the per-user PHP Selector versions wiped by alt-php's %postun.
    # Returns early if there's nothing to do.
    my $user_versions = Elevate::StageFile::read_stage_file('user_php_selectors');
    return unless ref $user_versions eq 'HASH' && scalar keys %$user_versions;

    my @failed;
    my $cli = '/usr/sbin/cloudlinux-selector';
    if ( -x $cli ) {
        INFO( sprintf( 'Restoring PHP Selector versions for %d user(s).', scalar keys %$user_versions ) );

        for my $user ( sort keys %$user_versions ) {
            my $version = $user_versions->{$user};

            my $sro = Cpanel::SafeRun::Object->new(
                program => $cli,
                args    => [ qw(set --json --interpreter=php), "--current-version=$version", "--user=$user" ],
            );

            if ( $sro->CHILD_ERROR() ) {
                WARN( "Could not restore user $user: " . $sro->autopsy );
                push @failed, $user;
            }
        }
    }
    else {
        WARN("Cannot restore PHP Selector versions: $cli is not executable on the target OS.");
        @failed = keys %$user_versions;
    }

    if ( scalar @failed ) {
        my $list = join "\n", map { "  - user: $_, PHP version $user_versions->{$_}" } @failed;
        WARN("Failed to restore PHP Selector versions for the following users:\n$list");
        Elevate::Notify::add_final_notification(
            "elevate-cpanel could not restore PHP Selector versions for these users (alt-php's %postun reset them to 'native' during stage 2):\n$list\n\nPlease run 'cloudlinux-selector set --interpreter=php --current-version=<v> --user=<u>' for each.",
            1
        );
    }

    return;
}

sub _snapshot_php_fpm_services ($self) {

    # Capture which alt-php{NN}-fpm and ea-php{NN}-php-fpm services are
    # currently enabled. Both package families' %preun runs `systemctl disable`
    # on full uninstall, and reinstallation does not re-enable the units, so
    # we replay the enabled state in stage 4.
    my @lines = split /\n/, Cpanel::SafeRun::Simple::saferunnoerror(qw(/usr/bin/systemctl list-unit-files --no-legend --no-pager alt-php*-fpm.service ea-php*-php-fpm.service));

    my @enabled;
    for my $line (@lines) {
        next unless $line =~ /^(\S+)\s+enabled\b/;
        push @enabled, $1;
    }

    return unless scalar @enabled;

    INFO( sprintf( 'Recorded %d PHP-FPM service(s) currently enabled.', scalar @enabled ) );
    Elevate::StageFile::update_stage_file( { 'php_fpm_services_enabled' => [ sort @enabled ] } );
    return;
}

sub _restore_php_fpm_services ($self) {

    # Re-enable PHP-FPM units disabled by alt-php-*-php-fpm and ea-php-*-php-fpm
    # %preun. systemctl enable is idempotent, so units that are already enabled
    # (e.g. via systemd presets on reinstall) are a no-op.
    my $services = Elevate::StageFile::read_stage_file('php_fpm_services_enabled');
    return unless ref $services eq 'ARRAY' && scalar @$services;

    INFO( sprintf( 'Re-enabling %d PHP-FPM service(s).', scalar @$services ) );

    my @failed;
    for my $unit (@$services) {
        my $sro = Cpanel::SafeRun::Object->new(
            program => '/usr/bin/systemctl',
            args    => [ qw(enable), $unit ],
        );

        if ( $sro->CHILD_ERROR() ) {
            WARN( "Could not re-enable $unit: " . $sro->autopsy );
            push @failed, $unit;
        }
    }

    if ( scalar @failed ) {
        my $list = join "\n", map { "  - $_" } @failed;
        WARN("Failed to re-enable PHP-FPM services:\n$list");
        Elevate::Notify::add_final_notification(
            "elevate-cpanel could not re-enable these PHP-FPM services (disabled by RPM %preun during stage 2):\n$list\n\nPlease enable them manually with 'systemctl enable <unit>'.",
            1
        );
    }

    return;
}

sub _remove_ea4_repo ($self) {
    unlink '/etc/yum.repos.d/EA4.repo';
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

sub _restore_ea_prefix_packages ($self) {

    my $packages = Elevate::StageFile::read_stage_file('ea_prefix_packages_to_restore');
    return unless ref $packages eq 'ARRAY' && @$packages;

    my @missing = $self->_ea_prefix_packages_missing($packages);
    return unless @missing;

    INFO( sprintf( 'Reinstalling %d ea-prefix package(s) not restored by ea_install_profile.', scalar @missing ) );

    eval { Elevate::PkgMgr::install_with_options( ['--skip-broken'], \@missing ); 1 } or do {
        WARN( "ea-prefix reinstall raised an error: " . ( $@ || 'unknown' ) );
    };

    my @still_missing = $self->_ea_prefix_packages_missing( \@missing );
    return unless @still_missing;

    my $pkg_list = join "\n", map { "  - $_" } @still_missing;
    Elevate::Notify::add_final_notification(
        "elevate-cpanel removed the following ea-prefix packages in pre_distro_upgrade and could not reinstall them post-upgrade:\n$pkg_list\n\nPlease reinstall them manually once their target-OS dependencies are resolvable (e.g. dnf install <packages>).",
        1
    );

    return;
}

sub _ea_prefix_packages_missing ( $self, $packages ) {
    my $installed = Elevate::PkgMgr::get_installed_pkgs('ea-*');
    return grep { !exists $installed->{$_} } @$packages;
}

sub _restore_ea4_profile ($self) {

    my $stash      = Elevate::StageFile::read_stage_file();
    my $is_enabled = $stash->{'ea4'} && $stash->{'ea4'}->{'enable'};

    unless ($is_enabled) {
        WARN('Skipping EA4 restore. EA4 does not appear to be enabled on this system.');
        return;
    }

    # Ensure the EA4 repo file is installed since we remove it now
    Cpanel::EA4::Install::install_ea4_repo();

    my $json = $stash->{'ea4'}->{'profile'};
    unless ( length $json && -f $json && -s _ ) {
        WARN('Unable to restore EA4 profile. Is EA4 enabled?');
        INFO("Profile was backed up as: $json") if length $json;
        return;
    }

    my $failed = $self->ssystem( '/usr/local/bin/ea_install_profile', '--install', $json );
    $self->_restore_ea_prefix_packages() if $failed;

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

    my $ea4_config_files;
    if ( $self->_has_non_ea_prefix_packages() ) {
        my @supported_non_ea_prefix_packages = $self->_get_installed_non_ea_prefix_supported_packages();

        $ea4_config_files = Elevate::PkgMgr::get_config_files_for_pkg_prefix(
            'ea-*',
            @supported_non_ea_prefix_packages,
        );
    }
    else {
        $ea4_config_files = Elevate::PkgMgr::get_config_files_for_pkg_prefix('ea-*');
    }

    # Filter out any dropped packages since they will NOT be installed
    # post distro upgrade
    my $stash        = Elevate::StageFile::read_stage_file();
    my $dropped_pkgs = $stash->{'ea4'}->{'dropped_pkgs'} // {};
    foreach my $pkg ( sort keys %$dropped_pkgs ) {
        delete $ea4_config_files->{$pkg};
    }

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
    return if -e Elevate::Constants::SKIP_PRESERVE_PHP_VERSIONS;

    my $default_php_version       = Elevate::StageFile::read_stage_file('php_get_system_default_version');
    my $php_get_inherited_domains = Elevate::StageFile::read_stage_file('php_get_inherited_domains');
    my $vhost_versions            = Elevate::StageFile::read_stage_file('php_get_vhost_versions');

    return unless ref $vhost_versions eq 'ARRAY';
    return unless scalar $vhost_versions->@*;

    my $whmapi1_bin    = '/usr/local/cpanel/bin/whmapi1';
    my $desired_output = '--output=json';

    # Set the default PHP version to ensure that it does not change after the update
    if ( length $default_php_version ) {
        my @api_cmd = (
            $whmapi1_bin,
            $desired_output,
            'php_set_system_default_version',
            "version=$default_php_version",
        );

        my $out    = Cpanel::SafeRun::Simple::saferunnoerror(@api_cmd);
        my $result = eval { Cpanel::JSON::Load($out); } // {};

        my $api_string = join( ' ', @api_cmd );
        unless ( $result->{metadata}{result} ) {

            WARN(<<~"EOS");
            Unable to set the default PHP version back to its original version.
            To set it back to its original PHP version, execute the following
            command:

            $api_string
            EOS
        }
    }

    my %inherited_domains;
    if ( ref $php_get_inherited_domains eq 'ARRAY' ) {
        %inherited_domains = map { $_ => 1 } @$php_get_inherited_domains;
    }

    # Ensure sites maintain the same PHP version after the update
    foreach my $vhost_entry (@$vhost_versions) {
        my $version = $vhost_entry->{version};
        my $vhost   = $vhost_entry->{vhost};
        my $fpm     = $vhost_entry->{php_fpm};

        # Ensure that the domain stays inherited if it was inherited before the upgrade
        $version = 'inherit' if $inherited_domains{$vhost};

        my @api_cmd = (
            $whmapi1_bin,
            $desired_output,
            'php_set_vhost_versions',
            "version=$version",
            "vhost=$vhost",
            "php_fpm=$fpm",
        );

        my $out    = Cpanel::SafeRun::Simple::saferunnoerror(@api_cmd);
        my $result = eval { Cpanel::JSON::Load($out); } // {};

        my $api_string = join( ' ', @api_cmd );
        unless ( $result->{metadata}{result} ) {

            WARN(<<~"EOS");
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
    return if -e Elevate::Constants::SKIP_PRESERVE_PHP_VERSIONS;

    my $php_get_system_default_version = Elevate::EA4::php_get_system_default_version();
    Elevate::StageFile::remove_from_stage_file('php_get_system_default_version');
    Elevate::StageFile::update_stage_file( { php_get_system_default_version => $php_get_system_default_version } );

    my $php_get_vhost_versions = Elevate::EA4::php_get_vhost_versions();
    Elevate::StageFile::remove_from_stage_file('php_get_vhost_versions');
    Elevate::StageFile::update_stage_file( { php_get_vhost_versions => $php_get_vhost_versions } );

    my $php_get_inherited_domains = Elevate::EA4::php_get_inherited_domains();
    Elevate::StageFile::remove_from_stage_file('php_get_inherited_domains');
    Elevate::StageFile::update_stage_file( { php_get_inherited_domains => $php_get_inherited_domains } );

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

    return $self->has_blocker(<<~"EOS");
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
        next if $pkg =~ m/^ea-noop-u20$/;                # ignore this package since it is specifically for ubuntu 20

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

=head2 _get_installed_non_ea_prefix_supported_packages 

The EA4 support for non-ea prefix's is described here:

https://github.com/webpros-cpanel/ea-cpanel-tools#ea4-packages-that-do-not-have-the-ea--prefix-in-their-name

NOTE: The code below is taken from ea_install_profile provided via ea-cpanel-tools
      so we are gathering these additional prefixes in the same manner that EA4 does

=cut

my @server_pkgs;

sub _get_installed_non_ea_prefix_supported_packages ($self) {
    return @server_pkgs if scalar @server_pkgs;

    return if $Cpanel::PackMan::VERSION < 0.03;

    my @addl_prefixes = eval {
        map { $_->basename } Path::Tiny::path("/etc/cpanel/ea4/additional-pkg-prefixes/")->children;
    };

    # Do not make the expensive call to Cpanel::PackMan unless there are
    # additional prefix files to check
    return unless scalar @addl_prefixes;

    my @supported_server_pkgs;
    for my $prefix (@addl_prefixes) {
        push @supported_server_pkgs, Cpanel::PackMan->instance->list( 'prefix' => "$prefix-" );
    }

    my $installed_packages = Elevate::PkgMgr::get_installed_pkgs();
    @server_pkgs = grep { exists $installed_packages->{$_} } @supported_server_pkgs;

    return @server_pkgs;
}

sub _has_non_ea_prefix_packages ($self) {
    my @additional_prefix_packages = $self->_get_installed_non_ea_prefix_supported_packages();
    return scalar @additional_prefix_packages > 0 ? 1 : 0;
}

1;
