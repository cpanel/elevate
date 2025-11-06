package Elevate::Components::Leapp;

=encoding utf-8

=head1 NAME

Elevate::Components::Leapp

=head2 check

Execute 'leapp preupgrade' and block if there are any inhibitors

=head2 pre_distro_upgrade

NOTE: This is here because this is being done specifically for leapp

1. Remove excludes line from '/etc/yum.conf'

=head2 post_distro_upgrade

noop

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::OS        ();

use parent qw{Elevate::Components::Base};

use Cwd           ();
use File::Copy    ();
use File::Slurper ();
use Log::Log4perl qw(:easy);

use constant YUM_CONF     => '/etc/yum.conf';
use constant YUM_CONF_BAK => '/etc/yum.conf.elevate_bak';

sub check ($self) {

    return if $self->is_check_mode();    # skip for --check

    return unless Elevate::OS::needs_leapp();

    return if $self->upgrade_distro_manually;    # skip when --upgrade-distro-manually is provided

    return if ( $self->components->num_blockers_found() > 0 );    # skip if any blockers have already been found

    $self->cpev->leapp->install();

    # Remove the excludes line from yum.conf before executing leapp preupgrade
    File::Copy::cp( YUM_CONF(), YUM_CONF_BAK() );
    $self->_remove_excludes();

    my $out = $self->cpev->leapp->preupgrade();

    # Restore the excludes line afterwards since this could fail and we are still running checks
    File::Copy::cp( YUM_CONF_BAK(), YUM_CONF() );

    # A return code of zero indicates that no inhibitors
    # or fatal errors have been found. I.e., success.
    return if ( $out->{status} == 0 );

    $self->_check_for_inhibitors();

    $self->_check_for_fatal_errors($out);

    if ( $self->components->num_blockers_found() > 0 ) {
        INFO('Leapp found issues which would prevent the upgrade, more information can be obtained in the files under /var/log/leapp');
    }

    return;
}

sub pre_distro_upgrade ($self) {
    $self->run_once("_remove_excludes");
    return;
}

sub _check_for_inhibitors ($self) {

    # Leapp will generate a JSON report file which contains any
    # inhibitors found. Find any reported inhibitors but exclude ones
    # that we know about and will fix before the upgrade.
    # (Inhibitors will also be reported in stdout in a block
    # labeled "UPGRADE INHIBITORS"; but more complete info is reported
    # in the JSON report file.)

    my $inhibitors = $self->cpev->leapp->search_report_file_for_inhibitors(
        qw(
          check_deprecated_rpm_signature
          check_detected_devices_and_drivers
          check_installed_devel_kernels
          cl_mysql_repository_setup
          network_deprecations
          persistentnetnamesdisable
          verify_check_results
        )
    );

    foreach my $inhibitor (@$inhibitors) {
        my $message = $inhibitor->{title} . "\n";
        $message .= $inhibitor->{summary} . "\n";
        if ( $inhibitor->{hint} ) {
            $message .= "Possible resolution: " . $inhibitor->{hint} . "\n";
        }
        if ( $inhibitor->{command} ) {
            $message .= "Consider running:" . "\n" . $inhibitor->{command} . "\n";
        }

        $self->has_blocker($message);
    }

    return;
}

sub _check_for_fatal_errors ( $self, $out ) {

    # Fatal errors will NOT be flagged as inhibitors in the
    # leapp reports.  So it is NOT possible to distinguish them from
    # any non-fatal conditions reported there.  So, we need to fish
    # them from stdout.

    my $error_block = $self->cpev->leapp->extract_error_block_from_output( $out->{stdout} );

    if ( length $error_block ) {
        $self->has_blocker( "Leapp encountered the following error(s):\n" . $error_block );
    }

    return;
}

sub _remove_excludes ($self) {
    return unless Elevate::OS::needs_leapp();

    my $yum_conf = YUM_CONF();

    INFO("Removing excludes from $yum_conf");
    my $txt   = eval { File::Slurper::read_text($yum_conf) };
    my @lines = split "\n", $txt;
    foreach my $line (@lines) {
        next unless $line =~ /^\s*exclude\s*=/;
        $line = '';
    }

    my $config = join "\n", @lines;
    $config .= "\n";
    File::Slurper::write_text( $yum_conf, $config );

    return;
}

1;
