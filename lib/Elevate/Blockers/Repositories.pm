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

use constant YUM_COMPLETE_TRANSACTION_BIN => '/usr/sbin/yum-complete-transaction';
use constant FIX_RPM_SCRIPT               => '/usr/local/cpanel/scripts/find_and_fix_rpm_issues';

sub check ($self) {
    my $ok = 1;
    $ok = 0 if $self->_blocker_packages_installed_without_associated_repo;
    $ok = 0 if $self->_blocker_invalid_yum_repos;
    $ok = 0 if $self->_yum_is_stable();

    return $ok;
}

sub _blocker_packages_installed_without_associated_repo ($self) {
    my @extra_packages = $self->yum->get_extra_packages();
    return unless scalar @extra_packages;

    my @packages   = map { $_->{package} } @extra_packages;
    my $pkg_string = join "\n", @packages;
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

        WARN("Initial run of \"yum makecache\" failed: $errors");
        WARN("Running \"yum clean all\" in an attempt to fix yum");

        my $ret = $self->ssystem_capture_output(qw{/usr/bin/yum clean all});
        if ( $ret->{status} != 0 ) {
            WARN( "Errors encountered running \"yum clean all\": " . $ret->{stderr} );
        }

        $errors = Cpanel::SafeRun::Errors::saferunonlyerrors(qw{/usr/bin/yum makecache});
        if ( $errors =~ m/\S/ms ) {
            ERROR('yum appears to be unstable. Please address this before upgrading');
            ERROR($errors);
            my $id = ref($self) . '::YumMakeCacheError';
            return $self->has_blocker(
                "yum appears to be unstable. Please address this before upgrading\n$errors",
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

1;
