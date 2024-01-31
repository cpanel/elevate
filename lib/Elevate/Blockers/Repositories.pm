package Elevate::Blockers::Repositories;

=encoding utf-8

=head1 NAME

Elevate::Blockers::Repositories

Blocker to check if the Yum repositories are compliant with the elevate process.

=cut

use cPstrict;

use Cpanel::OS   ();
use Cpanel::JSON ();

use Elevate::Constants ();
use Elevate::OS        ();

use parent qw{Elevate::Blockers::Base};

use Log::Log4perl qw(:easy);

# still used by disable_known_yum_repositories function
use constant DISABLE_MYSQL_YUM_REPOS => qw{
  Mysql57.repo
  Mysql80.repo

  MariaDB102.repo
  MariaDB103.repo
  MariaDB105.repo
  MariaDB106.repo

  mysql-community.repo
};

# FIXME use some RegExp...
use constant VETTED_MYSQL_YUM_REPO_IDS => qw{
  mysql-cluster-7.5-community
  mysql-cluster-7.5-community-source
  mysql-cluster-7.5-community-source
  mysql-cluster-7.6-community
  mysql-cluster-7.6-community-source
  mysql-cluster-7.6-community-source
  mysql-cluster-8.0-community
  mysql-cluster-8.0-community-debuginfo
  mysql-cluster-8.0-community-source
  mysql-connectors-community
  mysql-connectors-community-debuginfo
  mysql-connectors-community-source
  mysql-connectors-community-source
  mysql-tools-community
  mysql-tools-community-debuginfo
  mysql-tools-community-source
  mysql-tools-preview
  mysql-tools-preview-source
  mysql55-community
  mysql55-community-source
  mysql56-community
  mysql56-community-source
  mysql57-community
  mysql57-community-source
  mysql80-community
  mysql80-community-debuginfo
  mysql80-community-source
  MariaDB102
  MariaDB103
  MariaDB105
  MariaDB106
};

use constant VETTED_CLOUDLINUX_YUM_REPO => qw{
  cloudlinux
  cloudlinux-base
  cloudlinux-updates
  cloudlinux-extras
  cloudlinux-compat
  cloudlinux-imunify360
  cl-ea4
  cloudlinux-ea4
  cloudlinux-ea4-rollout
  cl-mysql
  cl-mysql-meta
  cloudlinux-elevate
  cloudlinux-rollout
};

use constant VETTED_YUM_REPO => qw{
  base
  c7-media
  centos-kernel
  centos-kernel-experimental
  centosplus
  cp-dev-tools
  cpanel-addons-production-feed
  cpanel-plugins
  cr
  ct-preset
  digitalocean-agent
  droplet-agent
  EA4
  EA4-c$releasever
  elasticsearch
  elasticsearch-7.x
  elevate
  elevate-source
  epel
  epel-testing
  extras
  fasttrack
  imunify360
  imunify360-ea-php-hardened
  imunify360-rollout-1
  imunify360-rollout-2
  imunify360-rollout-3
  imunify360-rollout-4
  imunify360-rollout-5
  imunify360-rollout-6
  imunify360-rollout-7
  imunify360-rollout-8
  influxdb
  kernelcare
  updates
  wp-toolkit-cpanel
  wp-toolkit-thirdparties
}, VETTED_MYSQL_YUM_REPO_IDS;

sub check ($self) {
    my $ok = 1;
    $ok = 0 unless $self->_blocker_system_update;
    $ok = 0 unless $self->_blocker_invalid_yum_repos;
    $ok = 0 unless $self->_blocker_unstable_yum;

    return $ok;
}

sub _blocker_invalid_yum_repos ($self) {
    my $status_hr = $self->_check_yum_repos();
    if ( _yum_status_hr_contains_blocker($status_hr) ) {
        my $msg = '';
        if ( $status_hr->{'INVALID_SYNTAX'} ) {
            $msg .= <<~'EOS';
            One or more enabled YUM repo are using invalid syntax.
            '\$' variables behave differently in repo files between RedHat 7 and RedHat 8.
            RedHat 7 interpolates '\$' variable whereas RedHat 8 does not.

            Please fix the files before continuing the update.
            EOS
        }
        if ( $status_hr->{'USE_RPMS_FROM_UNVETTED_REPO'} ) {
            $msg .= <<~'EOS';
            One or more enabled YUM repo are currently unsupported and have installed packages.
            You should disable these repositories and remove packages installed from them
            before continuing the update.
            EOS
        }

        if ( !$self->is_check_mode() ) {    # autofix when --check is not used
            $self->_autofix_yum_repos();

            # perform a second check to make sure we are in good shape
            $status_hr = $self->_check_yum_repos();
        }

        return 0 unless _yum_status_hr_contains_blocker($status_hr);

        for my $unsupported_repo ( @{ $self->{_yum_repos_unsupported_with_packages} } ) {
            my $blocker_id = ref($self) . '::' . $unsupported_repo->{'name'};
            $self->has_blocker( $unsupported_repo->{'json_report'}, 'blocker_id' => $blocker_id, 'quiet' => 1 );
        }
    }

    return 0;
}

sub _blocker_unstable_yum ($self) {
    $self->has_blocker(q[yum is not stable]) unless $self->_yum_is_stable();

    return 0;
}

sub _blocker_system_update ($self) {
    return 0 if $self->_system_update_check();
    return $self->has_blocker(q[System is not up to date]);
}

sub _yum_status_hr_contains_blocker ($status_hr) {
    return 0 if ref $status_hr ne 'HASH' || !scalar keys( %{$status_hr} );

    # Not using List::Util here already, so not gonna use first()
    my @blockers = qw{INVALID_SYNTAX USE_RPMS_FROM_UNVETTED_REPO};
    foreach my $blocked (@blockers) {
        return 1 if $status_hr->{$blocked};
    }
    return 0;
}

sub _yum_is_stable ($self) {
    my $errors = Cpanel::SafeRun::Errors::saferunonlyerrors(qw{/usr/bin/yum makecache});
    if ( $errors =~ m/\S/ms ) {
        ERROR('yum appears to be unstable. Please address this before upgrading');
        ERROR($errors);

        return 0;
    }

    if ( opendir( my $dfh, '/var/lib/yum' ) ) {
        my @transactions = grep { m/^transaction-all\./ } readdir $dfh;
        if (@transactions) {
            ERROR('There are unfinished yum transactions remaining. Please address these before upgrading. The tool `yum-complete-transaction` may help you with this task.');
            return 0;
        }
    }
    else {
        ERROR(qq{Could not read directory '/var/lib/yum': $!});
        return 0;
    }

    return 1;
}

# $status_hr = $self->_check_yum_repos()
#   check current repos:
#       UNVETTED is set when using packages from unvetted repo
#       INVALID_SYNTAX is set when one ore more repo use invalid syntax
#       USE_RPMS_FROM_UNVETTED_REPO is set when packages are installed from unvetted repo
#       HAS_UNUSED_REPO_ENABLED is set when packages are not installed from unvetted repo
#
sub _check_yum_repos ($self) {

    # (re)set the array to store the offending repo
    $self->{_yum_repos_path_using_invalid_syntax} = [];
    $self->{_yum_repos_to_disable}                = [];
    $self->{_yum_repos_unsupported_with_packages} = [];

    my @vetted_repos = (VETTED_YUM_REPO);
    push( @vetted_repos, VETTED_CLOUDLINUX_YUM_REPO ) if Elevate::OS::name() eq 'CloudLinux7';

    my %vetted = map { $_ => 1 } @vetted_repos;

    my $repo_dir = Elevate::Constants::YUM_REPOS_D;

    my %status;
    opendir( my $dh, $repo_dir ) or do {
        ERROR("Cannot read directory $repo_dir - $!");
        return;
    };
    foreach my $f ( readdir($dh) ) {
        next unless $f =~ m{\.repo$};
        my $path = "${repo_dir}/$f";

        next unless -f $path;

        my $txt = eval { File::Slurper::read_text($path) };

        next unless length $txt;
        my @lines = split( qr/\n/, $txt );
        my $current_repo_name;
        my $current_repo_enabled          = 1;
        my $current_repo_use_valid_syntax = 1;

        my $check_last_known_repo = sub {
            return unless length $current_repo_name;
            return unless $current_repo_enabled;

            my $temp_current_repo_name = $current_repo_name;

            # ignore the number on rollout mirrors
            # cloudlinux-rollout-1 becomes cloudlinux-rollout
            # cloudlinux-ea4-1 becomes cloudlinux-ea4
            # cloudlinux-ea4-rollout-1 becomes cloudlinux-ea4-rollout
            $current_repo_name = $1 if $current_repo_name =~ m/^(cloudlinux-(?:rollout|ea4)(?:-rollout)?)-[0-9]+$/;

            my $is_vetted = $vetted{$current_repo_name} || $vetted{ lc $current_repo_name };

            $current_repo_name = $temp_current_repo_name;

            if ( !$is_vetted ) {
                $status{'UNVETTED'} = 1;
                my @installed_packages = cpev::get_installed_rpms_in_repo($current_repo_name);
                if ( my $total_pkg = scalar @installed_packages ) {    # FIXME
                    ERROR(
                        sprintf(
                            "%d package(s) installed from unsupported YUM repo '%s' from %s",
                            $total_pkg,
                            $current_repo_name, $path
                        )
                    );
                    push(
                        $self->{_yum_repos_unsupported_with_packages}->@*,
                        {
                            'name'        => $current_repo_name,
                            'json_report' => Cpanel::JSON::canonical_dump( { 'name' => $current_repo_name, 'path' => $path, 'packages' => [ sort @installed_packages ] } )
                        }
                    );
                    $status{'USE_RPMS_FROM_UNVETTED_REPO'} = 1;
                }
                else {
                    INFO( sprintf( "Unsupported YUM repo enabled '%s' without packages installed from %s, these will be disabled before ELevation", $current_repo_name, $path ) );

                    # no packages installed need to disable it
                    push( $self->{_yum_repos_to_disable}->@*, $current_repo_name );
                    $status{'HAS_UNUSED_REPO_ENABLED'} = 1;
                }
            }
            elsif ( !$current_repo_use_valid_syntax ) {
                WARN( sprintf( "YUM repo '%s' is using unsupported '\\\$' syntax in %s", $current_repo_name, $path ) );
                unless ( grep { $_ eq $path } $self->{_yum_repos_path_using_invalid_syntax}->@* ) {
                    push( $self->{_yum_repos_path_using_invalid_syntax}->@*, $path );
                }
                $status{'INVALID_SYNTAX'} = 1;
            }
            return;
        };

        foreach my $line (@lines) {
            next if $line =~ qr{^\s*\#};       # skip comments
            $line =~ s{\s*\#.+$}{};            # strip comments
            if ( $line =~ qr{^\s*\[\s*(.+)\s*\]} ) {
                $check_last_known_repo->();

                $current_repo_name             = $1;
                $current_repo_enabled          = 1;    # assume enabled unless explicitely disabled
                $current_repo_use_valid_syntax = 1;

                next;
            }
            next unless defined $current_repo_name;

            $current_repo_enabled = 0 if $line =~ m{^\s*enabled\s*=\s*0};

            # the \$ syntax does not behave the same between 7 and 8
            $current_repo_use_valid_syntax = 0 if $line =~ m{\\\$};
        }

        # check the last repo found
        $check_last_known_repo->();
    }
    return \%status;
}

sub _autofix_yum_repos ($self) {

    if ( ref $self->{_yum_repos_path_using_invalid_syntax} ) {
        my @files_with_invalid_syntax = $self->{_yum_repos_path_using_invalid_syntax}->@*;

        foreach my $f (@files_with_invalid_syntax) {
            INFO( q[Fixing \$ variables in repo file: ] . $f );
            Cpanel::SafeRun::Simple::saferunnoerror( $^X, '-pi', '-e', 's{\\\\\$}{\$}g', $f );
        }
    }

    if ( ref $self->{_yum_repos_to_disable} ) {
        my @repos_to_disable = $self->{_yum_repos_to_disable}->@*;
        foreach my $repo (@repos_to_disable) {
            INFO(qq[Disabling unused yum repository: $repo]);
            Cpanel::SafeRun::Simple::saferunnoerror( qw{/usr/bin/yum-config-manager --disable}, $repo );
        }
    }

    return;
}

sub _system_update_check ($self) {

    INFO("Checking if your system is up to date: ");
    $self->ssystem(qw{/usr/bin/yum clean all});

    my $out = $self->ssystem_capture_output(qw{/usr/bin/yum check-update -q});

    if ( $out->{status} != 0 ) {

        # not a blocker: only a warning
        WARN("Your system is not up to date please run: /usr/bin/yum update");

        my $is_blocker;
        my $output = $out->{stdout} // [];
        foreach my $line (@$output) {
            next if $line =~ qr{^\s+$};
            next if $line =~ qr{^kernel};    # do not block if we need to update kernel packages
            $is_blocker = 1;
            last;
        }

        # not a blocker when only kernels packages need to be updated
        return if $is_blocker;
    }

    INFO("Checking /scripts/sysup");
    if ( $self->ssystem("/scripts/sysup") != 0 ) {
        WARN("/scripts/sysup failed, please fix it and rerun it before upgrading.");
        return;
    }

    return 1;
}

1;
