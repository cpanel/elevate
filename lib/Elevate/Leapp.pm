package Elevate::Leapp;

=encoding utf-8

=head1 NAME

Elevate::Leapp

Object to install and execute the leapp script

=cut

use cPstrict;

use Cpanel::Binaries       ();
use Cpanel::Exception      ();
use Cpanel::JSON           ();
use Cpanel::Kernel::Status ();
use Cpanel::LoadFile       ();
use Cpanel::Pkgr           ();

use Elevate::OS        ();
use Elevate::PkgMgr    ();
use Elevate::StageFile ();

use Config::Tiny ();
use File::Find   ();

use Log::Log4perl qw(:easy);

use constant LEAPP_REPORT_JSON       => q[/var/log/leapp/leapp-report.json];
use constant LEAPP_REPORT_TXT        => q[/var/log/leapp/leapp-report.txt];
use constant LEAPP_UPGRADE_LOG       => q[/var/log/leapp/leapp-upgrade.log];
use constant LEAPP_FAIL_CONT_FILE    => q[/var/cpanel/elevate_leap_fail_continue];
use constant LEAPP_COMPLETION_STRING => qr/Starting stage After of phase FirstBoot/;

use constant DNF => '/usr/bin/dnf';
use constant RPM => '/usr/bin/rpm';

# kmod-lve builds that require kmod at this epoch or higher are removed by leapp
# during the upgrade, because the CloudLinux 9 kmod carries a lower epoch.
use constant KMOD_LVE_REMOVED_KMOD_EPOCH => 2;

our $time_to_wait_for_leapp_completion = 10 * 60;

our $modules_dir = '/lib/modules';

use Simple::Accessor qw{
  cpev
};

sub _build_cpev {
    die q[Missing cpev];
}

sub install ($self) {

    unless ( Cpanel::Pkgr::is_installed('elevate-release') ) {
        my $elevate_rpm_url = Elevate::OS::elevate_rpm_url();
        Elevate::PkgMgr::install_pkg_via_url($elevate_rpm_url);
        $self->beta_if_enabled;    # If --leappbeta was passed, then enable it.
    }

    my $leapp_data_pkg = Elevate::OS::leapp_data_pkg();

    unless ( Cpanel::Pkgr::is_installed('leapp-upgrade') && Cpanel::Pkgr::is_installed($leapp_data_pkg) ) {
        Elevate::PkgMgr::install( 'leapp-upgrade', $leapp_data_pkg );
    }

    if ( Elevate::OS::needs_vdo() && Cpanel::Pkgr::is_installed('lvm2') && !Cpanel::Pkgr::is_installed('vdo') ) {
        Elevate::PkgMgr::install('vdo');
    }

    return;
}

sub beta_if_enabled ($self) {
    return unless $self->cpev->getopt('leappbeta');
    my $yum_config = Cpanel::Binaries::path('yum-config-manager');
    $self->cpev->ssystem_and_die( $yum_config, '--disable', Elevate::OS::leapp_repo_prod() );
    $self->cpev->ssystem_and_die( $yum_config, '--enable',  Elevate::OS::leapp_repo_beta() );

    return 1;
}

sub remove_kernel_devel ($self) {

    if ( Cpanel::Pkgr::is_installed('kernel-devel') ) {
        Elevate::PkgMgr::remove('kernel-devel');
    }

    return;
}

=head2 remove_leftover_kmod_lve

The CloudLinux 8 kmod-lve builds carry epoch 1, while the CloudLinux 9 builds
carry epoch 0.  Every CloudLinux 8 build declares C<Obsoletes: kmod-lve E<lt> 1:...>,
which the CloudLinux 9 package falls inside of on the epoch alone.

The newer CloudLinux 8 builds require C<kmod E<gt>= 2:...>, which the
CloudLinux 9 kmod cannot satisfy, so leapp removes them during the upgrade and
their obsoletes go with them.  Older builds (such as 2.0-43) predate that
requirement, so nothing removes them, and their obsoletes cause leapp's
dnf_transaction_check actor to fail.  kmod-lve is installonly, so these older
builds accumulate on long-lived servers.

Remove any such leftover builds.  The installed kernels require a kmod-lve
package, so if only leftover builds are installed, install the current build
first so that the leftovers can be removed.  dnf installs it without applying
the yum.conf excludes, and without pruning any installed build, so that nothing
is removed before the checks below.

Nothing is removed while the running or default boot kernel still loads its LVE
module from a leftover build.  The server reboots into the default boot kernel
before the upgrade completes, and the running kernel is held to the same rule
since ELevate expects the two to match.  Both are checked even if they are not
found among the installed kernels, and nothing is removed if either cannot be
determined.  Other installed kernels that rely on a leftover build only produce a
warning, since they run without LVE only if booted manually.  A module is only
counted as a replacement if a current kmod-lve build owns it, so a same-named
module that no package owns does not allow the leftovers to be removed.

Dies if the leftover builds cannot be removed.

=cut

sub remove_leftover_kmod_lve ($self) {
    return unless Elevate::OS::needs_leftover_kmod_lve_removal();

    my ( $leftover, $current ) = $self->_get_kmod_lve_pkgs();
    return unless @$leftover;

    if ( !@$current ) {
        INFO('Installing the current kmod-lve package so that superseded kmod-lve packages can be removed');

        # Installing an installonly package can prune older builds, which would
        # remove modules before the coverage guard below has checked them.  The
        # yum.conf excludes, which leapp preupgrade runs without, can match kmod-lve.
        $self->cpev->ssystem_and_die( DNF, '-y', '--disableexcludes=main', '--setopt=installonly_limit=0', 'upgrade', 'kmod-lve' );

        my @before = @$leftover;
        ( $leftover, $current ) = $self->_get_kmod_lve_pkgs();

        my %remaining = map { $_ => 1 } @$leftover;
        if ( my @gone = grep { !$remaining{$_} } @before ) {
            my $gone_list = join( "\n", map { "    $_" } @gone );
            die "Installing the current kmod-lve package unexpectedly removed superseded kmod-lve packages before checking whether a kernel loads LVE from them:\n$gone_list\n";
        }

        die "Unable to install a kmod-lve package that will be replaced during the upgrade\n" unless @$current;
    }

    my $pkg_list = join( "\n", map { "    $_" } @$leftover );

    my @booted = eval { _booted_kernels() };
    die "${@}\nThe superseded kmod-lve packages have not been removed:\n$pkg_list\n" unless @booted;

    my %booted  = map { $_ => 1 } @booted;
    my $reliant = $self->_kernels_relying_on_kmod_lve( $leftover, $current, \@booted );
    if (%$reliant) {
        if ( my @blocking = grep { $booted{$_} } sort keys %$reliant ) {
            my $kernel_list = _reliant_kernel_list( $reliant, \@blocking );
            die <<~"EOS";
            The running or default boot kernel may load LVE from a superseded kmod-lve package, and no current kmod-lve package provides a compatible module for it:
            $kernel_list

            The superseded kmod-lve packages have not been removed:
            $pkg_list
            EOS
        }

        my $kernel_list = _reliant_kernel_list( $reliant, [ sort keys %$reliant ] );
        WARN(<<~"EOS");
        The following installed kernels may load LVE from a superseded kmod-lve package, and no current kmod-lve package provides a compatible module for them.  ELevate does not boot these kernels, but they will not load LVE if they are booted manually before the upgrade completes:
        $kernel_list
        EOS
    }

    INFO("Removing superseded kmod-lve packages that would prevent the upgrade:\n$pkg_list");

    eval { $self->cpev->ssystem_and_die( RPM, '-e', @$leftover ); 1 } or die "Unable to remove the superseded kmod-lve packages:\n$pkg_list\n\n$@";

    return;
}

=head2 warn_leftover_kmod_lve

When the distro is upgraded manually, ELevate does not remove the leftover
kmod-lve builds described in L</remove_leftover_kmod_lve>.  Warn about any that
are installed, since leapp will fail on them unless the admin removes them.
Failing to query the installed builds only produces a warning, so that it
cannot stop a manual upgrade.

=cut

sub warn_leftover_kmod_lve ($self) {
    return unless Elevate::OS::needs_leftover_kmod_lve_removal();

    my $steps = kmod_lve_removal_steps();

    my ($leftover) = eval { $self->_get_kmod_lve_pkgs() };
    if ( !$leftover ) {
        WARN(<<~"EOS");
        Unable to check for superseded kmod-lve packages.  If any are installed, leapp's dnf_transaction_check will fail on them:
        $@
        List the installed builds with the following command.  Any build that does not require 'kmod >= 2:...' must be removed before the upgrade:

            for pkg in \$(rpm -q kmod-lve); do echo "\$pkg: \$(rpm -q --requires \$pkg | grep '^kmod ')"; done

        $steps
        EOS
        return;
    }
    return unless @$leftover;

    my $pkg_list = join( "\n", map { "    $_" } @$leftover );
    WARN(<<~"EOS");
    The following superseded kmod-lve packages are installed, and leapp's dnf_transaction_check will fail on them unless they are removed before the upgrade:
    $pkg_list

    $steps
    EOS

    return;
}

=head2 kmod_lve_removal_steps

Returns instructions for removing the leftover kmod-lve builds by hand without
leaving a kernel that will be booted without its LVE module.

=cut

sub kmod_lve_removal_steps () {
    return <<~'EOS';
    Before removing them, run the following command to see which kmod-lve
    package each installed kernel takes its LVE modules from.  A module in a
    kernel's own directories is listed without a link target:

        find /lib/modules/*/updates /lib/modules/*/extra /lib/modules/*/weak-updates \
            \( -name '*lve.ko*' -o -name 'iolimits.ko*' \) -printf '%p -> %l\n'

    Any kernel that relies on a superseded package will not load LVE if it is
    booted before the upgrade.  Install the current kmod-lve package, without
    letting dnf remove older builds, with:

        dnf --disableexcludes=main --setopt=installonly_limit=0 upgrade kmod-lve

    If it does not support the running or default boot kernel, update the
    kernel with 'dnf --disableexcludes=main upgrade kernel', make sure the new
    kernel is the default boot entry ('grubby --default-kernel'), and reboot
    into it.  Then remove the superseded packages with 'rpm -e'.
    EOS
}

# Returns the running and default boot kernel versions, or dies if either cannot
# be determined.
sub _booted_kernels () {
    my $status = eval { Cpanel::Kernel::Status::reboot_status() };
    if ( !$status ) {
        my $error = Cpanel::Exception::get_string_no_id($@);
        chomp $error;
        die "Unable to determine the running and boot kernels:\n$error\n";
    }

    my @kernels;
    foreach my $which (qw{ running boot }) {
        my $version = $status->{"${which}_version"} // '';
        die "Unable to determine the $which kernel\n" unless _is_kernel_version($version);
        push @kernels, $version;
    }

    return @kernels;
}

# The version names a directory under /lib/modules, so it must not be a path
sub _is_kernel_version ($version) {
    return 0 unless $version =~ m{^[A-Za-z0-9._+~-]+$};
    return 0 if $version     =~ m{^\.+$};
    return 1;
}

sub _reliant_kernel_list ( $reliant, $kernels ) {
    return join(
        "\n",
        map {
            my $k = $_;
            map { "    $k -> $_" } @{ $reliant->{$k} }
        } @$kernels
    );
}

# Returns two array refs: installed kmod-lve builds that leapp will not remove
# during the upgrade (leftovers), and current builds that it will replace.
sub _get_kmod_lve_pkgs ($self) {
    return ( [], [] ) unless Cpanel::Pkgr::is_installed('kmod-lve');

    my $out = $self->cpev->ssystem_hide_and_capture_output( RPM, '-q', '--qf', '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}|[%{OBSOLETENAME},]|[%{REQUIRENAME} %{REQUIREFLAGS:depflags} %{REQUIREVERSION},]\n', 'kmod-lve' );

    if ( $out->{status} != 0 ) {
        die "Unable to query the installed kmod-lve packages:\n" . join( "\n", @{ $out->{stderr} } ) . "\n";
    }

    my ( @leftover, @current );
    foreach my $line ( @{ $out->{stdout} } ) {
        my ( $pkg, $obsoletes, $requires ) = split( /\|/, $line, 3 );
        if ( !defined $requires ) {
            DEBUG("Skipping unexpected rpm output: $line");
            next;
        }

        my $removed_by_upgrade = grep { m/^kmod >= ([0-9]+):/ && $1 >= KMOD_LVE_REMOVED_KMOD_EPOCH } split( /,/, $requires );
        if ($removed_by_upgrade) {
            push @current, $pkg;
        }
        elsif ( grep { $_ eq 'kmod-lve' } split( /,/, $obsoletes ) ) {
            push @leftover, $pkg;
        }
    }

    return ( \@leftover, \@current );
}

# Returns a hash ref of kernel => [module paths] for each installed or booted kernel that
# would lose an LVE module once the leftover packages are removed.  Modules are
# matched by name, since each build installs into its own versioned directory,
# and a kernel loses a name when it has a leftover copy of it (its own, or through
# weak-updates) and no copy that a current kmod-lve build owns.  Any other copy,
# such as one that no package owns, does not count, since nothing shows it was
# built for the kernel.  That includes a kernel with only its own leftover
# module, which no current build was checked against.
#
# This relies on weak-modules having linked every compatible current module when
# the current build was installed, so a current module missing for a kernel is
# one it cannot load.  A name that no current build ships was renamed or dropped,
# and is excused for any kernel with a current module, since that module shows
# the current build supports the kernel.  Names the build still ships are not.
sub _kernels_relying_on_kmod_lve ( $self, $leftover, $current, $booted ) {
    my %removed = $self->_kmod_lve_modules($leftover)->%*;
    my $kept    = $self->_kmod_lve_modules($current);
    delete @removed{ keys %$kept };
    return {} unless %removed;

    my %shipped = map { $_ => 1 } values %$kept;
    my %names   = ( %shipped, map { $_ => 1 } values %removed );

    my %reliant;
    my %kernels = map { $_ => 1 } _installed_kernels(), @$booted;
    foreach my $kernel ( sort keys %kernels ) {
        my $copies    = _kernel_module_copies( $kernel, \%names );
        my $supported = grep { $kept->{$_} } map { @$_ } values %$copies;

        foreach my $name ( sort keys %$copies ) {
            next if $supported && !$shipped{$name};

            my @paths = @{ $copies->{$name} };
            my @lost  = grep { $removed{$_} } @paths;
            next unless @lost;
            next if grep { $kept->{$_} } @paths;
            push @{ $reliant{$kernel} }, @lost;
        }
    }

    return \%reliant;
}

# Returns a hash ref of module path => module name
sub _kmod_lve_modules ( $self, $pkgs ) {
    my $out = $self->cpev->ssystem_hide_and_capture_output( RPM, '-ql', @$pkgs );
    if ( $out->{status} != 0 ) {
        die "Unable to list the files in the kmod-lve packages:\n" . join( "\n", @{ $out->{stderr} } ) . "\n";
    }

    my %modules;
    foreach my $file ( @{ $out->{stdout} } ) {
        my $path = _normalize_module_path($file);
        my $name = _module_name($path) // next;
        next unless $path =~ m{^/lib/modules/[^/]+/.+/};
        $modules{$path} = $name;
    }

    return \%modules;
}

sub _module_name ($path) {
    return $path =~ m{/([^/]+)\.ko(?:\.[a-z]+)?$} ? $1 : undef;
}

sub _installed_kernels () {
    return map { m{^\Q$modules_dir\E/([^/]+)/vmlinuz$} ? $1 : () } glob("$modules_dir/*/vmlinuz");
}

# Returns a hash ref of module name => [paths] for the usable copies of the named
# modules in the directories a kernel loads external modules from, with links
# resolved.  Probes under $modules_dir, but returns paths as rpm lists them so
# that they can be compared with the package file lists.
sub _kernel_module_copies ( $kernel, $names ) {
    my %copies;
    my @dirs = grep { -d } map { "$modules_dir/$kernel/$_" } qw{ updates extra weak-updates };
    return \%copies unless @dirs;

    File::Find::find(
        {
            no_chdir => 1,
            wanted   => sub {
                my $name = _module_name($File::Find::name) // return;
                return unless $names->{$name};

                ( my $link = $File::Find::name ) =~ s{^\Q$modules_dir\E}{/lib/modules};
                my $path = _resolve_module_path($link) // return;

                push @{ $copies{$name} }, $path unless grep { $_ eq $path } @{ $copies{$name} // [] };
            },
        },
        @dirs
    );

    return \%copies;
}

use constant MAX_MODULE_LINKS => 10;

# Follows a chain of links from a module path, as rpm lists it, to the file it
# ends at.  Returns undef if the chain does not end at a file.
sub _resolve_module_path ($path) {
    foreach ( 1 .. MAX_MODULE_LINKS ) {
        $path = _normalize_module_path($path);
        ( my $on_disk = $path ) =~ s{^/lib/modules/}{$modules_dir/};

        return -f $on_disk ? $path : undef unless -l $on_disk;

        my $target = readlink($on_disk) // return;
        if ( $target !~ m{^/} ) {
            ( my $dir = $path ) =~ s{/[^/]+$}{};
            $target = "$dir/$target";
        }
        $path = $target;
    }

    return;
}

sub _normalize_module_path ($path) {
    my @parts;
    foreach my $part ( split m{/+}, $path ) {
        next if $part eq '' || $part eq '.';
        if   ( $part eq '..' ) { pop @parts }
        else                   { push @parts, $part }
    }

    my $normalized = '/' . join( '/', @parts );
    $normalized =~ s{^/usr/lib/modules/}{/lib/modules/};

    return $normalized;
}

sub preupgrade ($self) {

    INFO("Running leapp preupgrade checks");

    my $out = $self->cpev->ssystem_hide_and_capture_output( '/usr/bin/leapp', 'preupgrade' );

    INFO("Finished running leapp preupgrade checks");

    return $out;
}

sub upgrade ($self) {

    return if $self->cpev->upgrade_distro_manually();

    $self->cpev->run_once(
        setup_answer_file => sub {
            $self->setup_answer_file();
        },
    );

    my $leapp_flag = Elevate::OS::leapp_flag();
    my $leapp_bin  = '/usr/bin/leapp';
    my @leapp_args = ('upgrade');
    push( @leapp_args, $leapp_flag ) if $leapp_flag;

    INFO("Running leapp upgrade");

    my $ok = eval {
        local $ENV{LEAPP_OVL_SIZE} = Elevate::StageFile::read_stage_file('env')->{'LEAPP_OVL_SIZE'} || 3000;
        local @ENV{qw(LANG LANGUAGE LC_ALL LC_MESSAGES LC_CTYPE)} = qw(en_US.UTF-8) x 5;
        $self->cpev->ssystem_and_die( { keep_env => 1 }, $leapp_bin, @leapp_args );
        1;
    };

    return 1 if $ok;

    $self->_report_leapp_failure_and_die();
    return;
}

sub search_report_file_for_inhibitors ( $self, @ignored_blockers ) {

    my @blockers;
    my $leapp_json_report = LEAPP_REPORT_JSON;

    if ( !-e $leapp_json_report ) {
        ERROR("Leapp did not generate the expected report file: $leapp_json_report");
        return [
            {
                title   => "Leapp did not generate $leapp_json_report",
                summary => "It is expected that leapp generate a JSON report file",
            }
        ];
    }

    my $report = eval { Cpanel::JSON::LoadFile($leapp_json_report) } // {};
    if ( my $exception = $@ ) {
        ERROR("Unable to parse leapp report file ($leapp_json_report): $exception");
        return [
            {
                title   => "Unable to parse leapp report file $leapp_json_report",
                summary => "The JSON report file generated by LEAPP is unreadable or corrupt",
            }
        ];
    }

    my $entries = $report->{entries};
    return [] unless ( ref $entries eq 'ARRAY' );

    foreach my $entry (@$entries) {
        next unless ( ref $entry eq 'HASH' );

        # If it is a blocker, then it will contain an array
        # of flags one of which will be named "inhibitor"
        my $flags = $entry->{flags};
        next unless ( ref $flags eq 'ARRAY' );
        next unless scalar grep { $_ eq 'inhibitor' } @$flags;

        # Some blockers we ignore because we fix them before upgrade
        next if scalar grep { $_ eq $entry->{actor} } @ignored_blockers;

        my $blocker = {
            title   => $entry->{title},
            summary => $entry->{summary},
        };

        if ( ref $entry->{detail}{remediations} eq 'ARRAY' ) {
            foreach my $rem ( @{ $entry->{detail}{remediations} } ) {
                next unless ( $rem->{type} && $rem->{context} );
                if ( $rem->{type} eq 'hint' ) {
                    $blocker->{hint} = $rem->{context};
                }
                if ( $rem->{type} eq 'command' && ref $rem->{context} eq 'ARRAY' ) {
                    $blocker->{command} = join ' ', @{ $rem->{context} };
                }
            }
        }

        push @blockers, $blocker;
    }

    return \@blockers;
}

sub extract_error_block_from_output ( $self, $text_ar ) {

    # The fatal errors will appear there in a block that looks like this:
    # =========================================
    #               ERRORS
    # =========================================
    #
    # Info about the errors
    #
    # =========================================
    #             END OF ERRORS
    # =========================================

    my $error_block = '';

    my $found_banner_line        = 0;
    my $found_second_banner_line = 0;
    my $in_error_block           = 0;

    foreach my $line (@$text_ar) {

        # Keep looking for a "banner" line (a line full of "=")
        if ( !$found_banner_line ) {
            $found_banner_line = 1 if $line =~ /^={10}/;
            next;
        }

        # We've found the banner line, check if this is the error block
        if ( !$in_error_block ) {
            if ( $line =~ /^\s+ERRORS/ ) {
                $in_error_block = 1;
            }
            else {
                # not the error block, go back to looking for a banner line
                $found_banner_line = 0;
            }
            next;
        }

        # We can't start harvesting the error info until we pass the second banner line
        if ( !$found_second_banner_line ) {
            $found_second_banner_line = 1 if $line =~ /^={10}/;
            next;
        }

        # If we come across another banner line, we are done with the error block
        last if $line =~ /^={10}/;

        $error_block .= $line . "\n";
    }

    return $error_block;
}

# Returns 0 on failure.

sub wait_for_leapp_completion ($self) {
    return 1 unless Elevate::OS::needs_leapp();

    # No use waiting for leapp to complete if we did not run leapp
    return 1 if $self->cpev->upgrade_distro_manually();

    my $upgrade_log = LEAPP_UPGRADE_LOG;

    if ( !-e $upgrade_log ) {
        ERROR("No LEAPP upgrade log detected at [$upgrade_log]");
        return 0;
    }

    my $elapsed    = 0;
    my $sleep_time = 3;    # Time to sleep, in seconds, between checks

    # Wait to see the completion message from leapp. It may take a little after boot.
    while ( $elapsed < $time_to_wait_for_leapp_completion ) {
        my $contents = Cpanel::LoadFile::loadfile(LEAPP_UPGRADE_LOG) // '';
        return 1 if $contents =~ LEAPP_COMPLETION_STRING;

        # Check each loop so they can drop the skip file in live.
        if ( -e LEAPP_FAIL_CONT_FILE ) {
            INFO( 'LEAPP does not appear to have completed successfully, but continuing anyway because [' . LEAPP_FAIL_CONT_FILE . '] exists' );
            return 2;
        }

        if ( $elapsed % 30 == 0 ) {
            INFO('Waiting for the LEAPP upgrade process to complete.');
            if ( $elapsed == 0 ) {    # First loop give extra advice
                INFO( 'This process may take up to ' . int( $time_to_wait_for_leapp_completion / 60 ) . ' minutes.' );
                INFO( 'You can `touch ' . LEAPP_FAIL_CONT_FILE . '` if you would like to skip this check.' );
            }
        }

        sleep $sleep_time;
        $elapsed += $sleep_time;
    }

    # We failed to find the completion message within 10 minutes.

    my $touch_file = LEAPP_FAIL_CONT_FILE;
    my $leapp_txt  = LEAPP_REPORT_TXT;
    my $msg        = <<~"END";
    The command 'leapp upgrade' did not complete successfully. Please investigate and resolve the issue.
    Once resolved, you can continue the upgrade by running the following commands:
        touch $touch_file
        /scripts/elevate-cpanel --continue
    The following log files may help in your investigation.
        $upgrade_log
        $leapp_txt
    END
    ERROR($msg);

    return 0;
}

sub _report_leapp_failure_and_die ($self) {

    my $msg = <<'EOS';
The 'leapp upgrade' process failed.

Please investigate, resolve then re-run the following command to continue the update:

    /scripts/elevate-cpanel --continue

EOS

    my $entries = $self->search_report_file_for_inhibitors;
    if ( ref $entries eq 'ARRAY' ) {
        foreach my $e (@$entries) {
            $msg .= "\n$e->{summary}" if $e->{summary};

            if ( $e->{command} ) {

                my $cmd = $e->{command};
                $cmd =~ s[^leapp][/usr/bin/leapp];

                $msg .= "\n\n";
                $msg .= <<"EOS";
Consider running this command:

    $cmd

EOS
            }
        }
    }

    if ( -e LEAPP_REPORT_TXT ) {
        $msg .= qq[\nYou can read the full leapp report at: ] . LEAPP_REPORT_TXT;
    }

    die qq[$msg\n];
}

sub setup_answer_file ($self) {
    my $leapp_dir = '/var/log/leapp';
    mkdir $leapp_dir unless -d $leapp_dir;

    my $answerfile_path = $leapp_dir . '/answerfile';
    system touch => $answerfile_path unless -e $answerfile_path;

    my $do_write;    # no point in overwriting the file if nothing needs to change

    my $ini_obj = Config::Tiny->read( $answerfile_path, 'utf8' );
    LOGDIE( 'Failed to read leapp answerfile: ' . Config::Tiny->errstr ) unless $ini_obj;

    my $SECTION = 'remove_pam_pkcs11_module_check';

    if ( not defined $ini_obj->{$SECTION}->{'confirm'} or $ini_obj->{$SECTION}->{'confirm'} ne 'True' ) {
        $do_write = 1;
        $ini_obj->{$SECTION}->{'confirm'} = 'True';
    }

    if ($do_write) {
        $ini_obj->write( $answerfile_path, 'utf8' )    #
          or LOGDIE( 'Failed to write leapp answerfile: ' . $ini_obj->errstr );
    }

    return;
}

1;
