package Elevate::Components::Repositories;

=encoding utf-8

=head1 NAME

Elevate::Components::Repositories

=head2 check

1. Determine if there are installed packages without an associated repo
2. Determine if there are invalid/unvetted repos being used
3. Verify that yum is stable

=head2 pre_distro_upgrade

1. Remove yum-plugin-fastestmirror
2. Remove known mysql yum repo files

=head2 post_distro_upgrade

noop

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::OS        ();
use Elevate::RPM       ();

use Cpanel::SafeRun::Simple ();
use Cwd                     ();
use File::Copy              ();
use Log::Log4perl           qw(:easy);

use parent qw{Elevate::Components::Base};

use constant YUM_COMPLETE_TRANSACTION_BIN => '/usr/sbin/yum-complete-transaction';
use constant FIX_RPM_SCRIPT               => '/usr/local/cpanel/scripts/find_and_fix_rpm_issues';

use constant EXPECTED_EXTRA_PACKAGES => (
    qr/^cpanel-/,
    qr/^easy-/,
    qr/^kernel/,
    qr/^mysql/i,
    qr/^plesk-/,
    'basesystem',
    'filesystem',
    'grub',
    'grubby',
    'python35',
    'python38-opt',
    'virt-what',
    'vzdummy-systemd-el7',
  ),
  Elevate::Constants::R1SOFT_AGENT_PACKAGES,
  Elevate::Constants::ACRONIS_OTHER_PACKAGES;

sub pre_distro_upgrade ($self) {

    $self->run_once("_disable_yum_plugin_fastestmirror");
    $self->run_once("_disable_known_yum_repositories");
    $self->run_once("_fixup_epel_repo");

    return;
}

sub _disable_known_yum_repositories {

    # remove all MySQL repos
    my @repo_files = map { Elevate::Constants::YUM_REPOS_D . '/' . $_ } Elevate::OS::disable_mysql_yum_repos();

    foreach my $f (@repo_files) {
        next unless -e $f;
        if ( -l $f ) {
            unlink $f;
            next;
        }

        File::Copy::mv( $f, "$f.off" ) or die qq[Failed to disable repo $f];
    }

    Cpanel::SafeRun::Simple::saferunnoerror(qw{/usr/bin/yum clean all});

    return;
}

sub _disable_yum_plugin_fastestmirror ($self) {
    my $pkg = 'yum-plugin-fastestmirror';
    $self->_erase_package($pkg);
    return;
}

sub _fixup_epel_repo ($self) {

    my $repo_file = Elevate::Constants::YUM_REPOS_D . '/epel.repo';

    if ( -e $repo_file ) {
        unlink($repo_file) or ERROR("Could not delete $repo_file: $!");
    }

    my $err = $self->ssystem(qw{/usr/bin/rpm -Uv --force https://archives.fedoraproject.org/pub/archive/epel/7/x86_64/Packages/e/epel-release-7-14.noarch.rpm});
    ERROR("Error installing epel-release: $err") if $err;

    return;
}

sub _erase_package ( $self, $pkg ) {
    return unless Cpanel::Pkgr::is_installed($pkg);
    $self->rpm->remove_no_dependencies($pkg);
    return;
}

sub check ($self) {
    my $ok = 1;
    $ok = 0 if $self->_blocker_packages_installed_without_associated_repo;
    $ok = 0 if $self->_blocker_invalid_yum_repos;
    $ok = 0 if $self->_yum_is_stable();

    return $ok;
}

sub _blocker_packages_installed_without_associated_repo ($self) {
    my @extra_packages = map { $_->{package} } $self->yum->get_extra_packages();

    my @unexpected_extra_packages;
    foreach my $pkg (@extra_packages) {
        next if grep { $pkg =~ m/$_/ } EXPECTED_EXTRA_PACKAGES();
        push @unexpected_extra_packages, $pkg;
    }

    return unless scalar @unexpected_extra_packages;

    my $pkg_string = join "\n", @unexpected_extra_packages;
    return $self->has_blocker( <<~EOS );
    There are packages installed that do not have associated repositories:

    $pkg_string
    EOS
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
            $self->_autofix_duplicate_repoids();

            # perform a second check to make sure we are in good shape
            $status_hr = $self->_check_yum_repos();
        }

        return 0 unless _yum_status_hr_contains_blocker($status_hr);

        if ( $status_hr->{DUPLICATE_IDS} ) {
            my $duplicate_ids = join "\n", keys $self->{_duplicate_repoids}->%*;
            my $dupe_id_msg   = <<~"EOS";
            One or more enable YUM repo have repositories defined multiple times:

            $duplicate_ids

            A possible resolution for this issue is to either remove the duplicate
            repository definitions or change the repoids of the conflicting
            repositories on the system to prevent the conflict.
            EOS

            my $blocker_id = ref($self) . '::' . 'DuplicateRepoIds';
            $self->has_blocker(
                $dupe_id_msg,
                blocker_id => $blocker_id,
            );
        }

        for my $unsupported_repo ( @{ $self->{_yum_repos_unsupported_with_packages} } ) {
            my $blocker_id = ref($self) . '::' . $unsupported_repo->{'name'};
            $self->has_blocker(
                $msg,
                info       => $unsupported_repo->{info},
                blocker_id => $blocker_id,
                quiet      => 1,
            );

        }
    }

    return 1;
}

sub _yum_status_hr_contains_blocker ($status_hr) {
    return 0 if ref $status_hr ne 'HASH' || !scalar keys( %{$status_hr} );

    # Not using List::Util here already, so not gonna use first()
    my @blockers = qw{INVALID_SYNTAX USE_RPMS_FROM_UNVETTED_REPO DUPLICATE_IDS};
    foreach my $blocked (@blockers) {
        return 1 if $status_hr->{$blocked};
    }
    return 0;
}

sub _yum_is_stable ($self) {
    my $errors = Cpanel::SafeRun::Errors::saferunonlyerrors(qw{/usr/bin/yum makecache});
    if ( $errors =~ m/\S/ms ) {

        my $error_msg = <<~'EOS';
        '/usr/bin/yum makecache' failed to return cleanly. This could be due to a temporary mirror problem, or it could indicate a larger issue, such as a broken repository. Since this script relies heavily on yum, you will need to address this issue before upgrading.

        If you need assistance, open a ticket with cPanel Support, as outlined here:

        https://docs.cpanel.net/knowledge-base/technical-support-services/how-to-open-a-technical-support-ticket/
        EOS

        WARN("Initial run of \"yum makecache\" failed: $errors");
        WARN("Running \"yum clean all\" in an attempt to fix yum");

        my $ret = $self->ssystem_capture_output(qw{/usr/bin/yum clean all});
        if ( $ret->{status} != 0 ) {
            WARN( "Errors encountered running \"yum clean all\": " . $ret->{stderr} );
        }

        $errors = Cpanel::SafeRun::Errors::saferunonlyerrors(qw{/usr/bin/yum makecache});
        if ( $errors =~ m/\S/ms ) {
            ERROR($error_msg);
            ERROR($errors);
            my $id = ref($self) . '::YumMakeCacheError';
            return $self->has_blocker(
                "$error_msg" . "$errors",
                info => {
                    name  => $id,
                    error => $errors,
                },
                blocker_id => $id,
                quiet      => 1,
            );
        }
    }

    if ( opendir( my $dfh, '/var/lib/yum' ) ) {
        my @transactions = grep { m/^transaction-all\./ } readdir $dfh;
        if (@transactions) {
            WARN('There are unfinished yum transactions remaining.');

            my $yum_ct_bin = YUM_COMPLETE_TRANSACTION_BIN();

            if ( $self->is_check_mode() ) {
                WARN("Unfinished yum transactions detected. Elevate will execute $yum_ct_bin --cleanup-only during upgrade");
            }
            else {
                if ( -x $yum_ct_bin ) {
                    INFO('Cleaning up unfinished yum transactions.');
                    my $ret = $self->ssystem_capture_output( $yum_ct_bin, '--cleanup-only' );
                    if ( $ret->{status} != 0 ) {
                        return $self->has_blocker( "Errors encountered running $yum_ct_bin: " . $ret->{stderr} );
                    }

                    $ret = $self->ssystem_capture_output(FIX_RPM_SCRIPT);
                    if ( $ret->{status} != 0 ) {
                        return $self->has_blocker( 'Errors encountered running ' . FIX_RPM_SCRIPT . ': ' . $ret->{stderr} );
                    }
                }
                else {
                    return $self->has_blocker( <<~EOS );
                    $yum_ct_bin is missing. You must install the yum-utils package
                    if you wish to clear the unfinished yum transactions.
                    EOS
                }
            }
        }
    }
    else {
        my $err = $!;    # Don't want to accidentally lose the error
        ERROR(qq{Could not read directory '/var/lib/yum': $err});
        my $id = ref($self) . '::YumDirUnreadable';

        return $self->has_blocker(
            qq{Could not read directory '/var/lib/yum': $err},
            info => {
                name  => $id,
                error => $err,
            },
            blocker_id => $id,
            quiet      => 1,
        );
    }

    return 0;
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
    $self->{_duplicate_repoids}                   = [];

    my @vetted_repos = Elevate::OS::vetted_yum_repo();

    my $repo_dir = Elevate::Constants::YUM_REPOS_D;

    my %status;
    my %repoids;
    my %duplicate_repoids;
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

            my $is_vetted = grep { $current_repo_name =~ m/$_/ } @vetted_repos;

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
                            name => $current_repo_name,
                            info => {
                                name         => $current_repo_name,
                                path         => $path,
                                num_packages => scalar @installed_packages,
                                packages     => [ sort @installed_packages ],
                            },
                        },
                    );
                    $status{'USE_RPMS_FROM_UNVETTED_REPO'} = 1;
                }
                else {
                    return unless $current_repo_enabled;

                    INFO( sprintf( "Unsupported YUM repo enabled '%s' without packages installed from %s, these will be disabled before ELevation", $current_repo_name, $path ) );

                    # no packages installed need to disable it
                    push( $self->{_yum_repos_to_disable}->@*, $current_repo_name );
                    $status{'HAS_UNUSED_REPO_ENABLED'} = 1;
                }
            }
            elsif ( !$current_repo_use_valid_syntax ) {
                return unless $current_repo_enabled;

                WARN( sprintf( "YUM repo '%s' is using unsupported '\\\$' syntax in %s", $current_repo_name, $path ) );
                unless ( grep { $_ eq $path } $self->{_yum_repos_path_using_invalid_syntax}->@* ) {
                    my $blocker_id = ref($self) . '::YumRepoConfigInvalidSyntax';

                    $self->has_blocker(
                        sprintf( "YUM repo '%s' is using unsupported '\\\$' syntax in %s", $current_repo_name, $path ),
                        info => {
                            name       => $blocker_id,
                            error      => 'YUM repository has unsupported syntax',
                            repository => $current_repo_name,
                            path       => $path,
                        },
                        blocker_id => $blocker_id,
                        quiet      => 1,
                    );

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

                # Check for duplicate repo IDs
                if ( $repoids{$current_repo_name} ) {
                    $duplicate_repoids{$current_repo_name} = $path;
                }
                $repoids{$current_repo_name} = 1;

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

    if ( scalar keys %duplicate_repoids ) {
        $status{DUPLICATE_IDS} = 1;
        $self->{_duplicate_repoids} = \%duplicate_repoids;
    }

    return \%status;
}

sub _autofix_duplicate_repoids ($self) {
    my %duplicate_ids = $self->{_duplicate_repoids}->%*;
    foreach my $id ( keys %duplicate_ids ) {
        if ( $id =~ m/^MariaDB[0-9]+/ ) {
            my $path = $duplicate_ids{$id};
            File::Copy::mv( $path, "$path.disabled_by_elevate" );
        }
    }

    return;
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

1;
