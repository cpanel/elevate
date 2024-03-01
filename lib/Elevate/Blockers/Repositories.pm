package Elevate::Blockers::Repositories;

=encoding utf-8

=head1 NAME

Elevate::Blockers::Repositories

Blocker to check if the Yum repositories are compliant with the elevate process.

=cut

use cPstrict;

use Cpanel::OS             ();
use Cpanel::JSON           ();
use Cpanel::Update::Config ();

use Elevate::Constants ();
use Elevate::OS        ();

use parent qw{Elevate::Blockers::Base};

use Log::Log4perl qw(:easy);

sub check ($self) {
    my $ok = 1;
    $ok = 0 unless $self->_system_update_check();
    $ok = 0 unless $self->_blocker_invalid_yum_repos;
    $ok = 0 unless $self->_yum_is_stable();

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
            $self->has_blocker(
                $msg,
                info       => $unsupported_repo->{info},
                blocker_id => $blocker_id,
                quiet      => 1,
            );

        }
    }

    return 0;
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
        my $id = ref($self) . '::YumMakeCacheError';
        $self->has_blocker(
            "yum appears to be unstable. Please address this before upgrading\n$errors",
            info => {
                name  => $id,
                error => $errors,
            },
            blocker_id => $id,
            quiet      => 1,
        );

        return 0;
    }

    if ( opendir( my $dfh, '/var/lib/yum' ) ) {
        my @transactions = grep { m/^transaction-all\./ } readdir $dfh;
        if (@transactions) {
            ERROR('There are unfinished yum transactions remaining. Please address these before upgrading. The tool `yum-complete-transaction` may help you with this task.');
            my $id = ref($self) . '::YumUnfinishedTransactions';

            $self->has_blocker(
                'There are unfinished yum transactions remaining. Please address these before upgrading. The tool `yum-complete-transaction` may help you with this task.',
                info => {
                    name         => $id,
                    error        => 'YUM has unfinished transactions',
                    transactions => join( "\n", sort @transactions ),
                },
                blocker_id => $id,
                quiet      => 1,
            );

            return 0;
        }
    }
    else {
        my $err = $!;    # Don't want to accidentally lose the error
        ERROR(qq{Could not read directory '/var/lib/yum': $err});
        my $id = ref($self) . '::YumDirUnreadable';

        $self->has_blocker(
            qq{Could not read directory '/var/lib/yum': $err},
            info => {
                name  => $id,
                error => $err,
            },
            blocker_id => $id,
            quiet      => 1,
        );

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

    my @vetted_repos = Elevate::OS::vetted_yum_repo();

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
                    INFO( sprintf( "Unsupported YUM repo enabled '%s' without packages installed from %s, these will be disabled before ELevation", $current_repo_name, $path ) );

                    # no packages installed need to disable it
                    push( $self->{_yum_repos_to_disable}->@*, $current_repo_name );
                    $status{'HAS_UNUSED_REPO_ENABLED'} = 1;
                }
            }
            elsif ( !$current_repo_use_valid_syntax ) {
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

    # Avoid yum splitting the outdated pacakges list to multiple lines
    # so that we can systematically parse it
    my $out = $self->ssystem_capture_output(q{/usr/bin/yum check-update -q | xargs -n3});

    # Can not just check the exit code since xargs -n3 always returns 0
    # Could set pipefail but that makes the above command even more complicated
    # Just check that stdout has a list to parse instead
    my $output = $out->{stdout} // [];
    if ( scalar @$output > 1 || $output->[0] ) {

        # not a blocker: only a warning
        WARN("Your system is not up to date please run: /usr/bin/yum update");

        my $is_blocker;
        my %repos_with_outdated_packages;
        foreach my $line (@$output) {
            next if $line =~ qr{^\s+$};
            next if $line =~ qr{^kernel};    # do not block if we need to update kernel packages
            $is_blocker = 1;

            if ( my ( $pkg_name, $pkg_version, $pkg_repo ) = split( /\s+/, $line ) ) {
                $repos_with_outdated_packages{"outdated_count_for_$pkg_repo"}++;
            }
        }

        # not a blocker when only kernels packages need to be updated
        if ($is_blocker) {

            my %cpupdate     = Cpanel::Update::Config::load();
            my $rpmup_status = $cpupdate{RPMUP};

            my $blocker_id = ref($self) . '::YumOutOfDate';
            $self->has_blocker(
                'YUM reports there are out of date packages',
                info => {
                    name  => $blocker_id,
                    error => 'YUM reports there are out of date packages',
                    rpmup => $rpmup_status,
                    %repos_with_outdated_packages,
                },
                'blocker_id' => $blocker_id,
                'quiet'      => 1
            );

            return;
        }
    }

    INFO("Checking /scripts/sysup");
    if ( $self->ssystem("/scripts/sysup") != 0 ) {
        WARN("/scripts/sysup failed, please fix it and rerun it before upgrading.");
        return;
    }

    return 1;
}

1;
