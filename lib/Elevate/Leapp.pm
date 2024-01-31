package Elevate::Leapp;

=encoding utf-8

=head1 NAME

Elevate::Leapp

Object to install and execute the leapp script

=cut

use cPstrict;

use Cpanel::JSON ();
use Cpanel::Pkgr ();

use Elevate::OS  ();
use Elevate::YUM ();

use Config::Tiny ();

use Log::Log4perl qw(:easy);

use constant LEAPP_REPORT_JSON => q[/var/log/leapp/leapp-report.json];
use constant LEAPP_REPORT_TXT  => q[/var/log/leapp/leapp-report.txt];

use Simple::Accessor qw{
  cpev
  yum
};

sub _build_cpev {
    die q[Missing cpev];
}

sub _build_yum ($self) {
    return Elevate::YUM->new( cpev => $self->cpev() );
}

sub install ($self) {

    unless ( Cpanel::Pkgr::is_installed('elevate-release') ) {
        my $elevate_rpm_url = Elevate::OS::elevate_rpm_url();
        $self->yum->install_rpm_via_url($elevate_rpm_url);
    }

    my $leapp_data_pkg = Elevate::OS::leapp_data_pkg();

    unless ( Cpanel::Pkgr::is_installed('leapp-upgrade') && Cpanel::Pkgr::is_installed($leapp_data_pkg) ) {
        $self->yum->install( 'leapp-upgrade', $leapp_data_pkg );
    }

    if ( Cpanel::Pkgr::is_installed('kernel-devel') ) {
        $self->yum->remove('kernel-devel');
    }

    return;
}

sub upgrade ($self) {

    return unless $self->cpev->should_run_leapp();

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
        local $ENV{LEAPP_OVL_SIZE} = cpev::read_stage_file('env')->{'LEAPP_OVL_SIZE'} || 3000;
        $self->cpev->ssystem_and_die( { keep_env => 1 }, $leapp_bin, @leapp_args );
        1;
    };

    return 1 if $ok;

    $self->_report_leapp_failure_and_die();
    return;
}

sub _report_leapp_failure_and_die ($self) {

    my $msg = <<'EOS';
The 'leapp upgrade' process failed.

Please investigate, resolve then re-run the following command to continue the update:

    /scripts/elevate-cpanel --continue

EOS

    my $leapp_json_report = LEAPP_REPORT_JSON;
    if ( -e $leapp_json_report ) {
        my $report = eval { Cpanel::JSON::LoadFile($leapp_json_report) } // {};

        my $entries = $report->{entries};
        if ( ref $entries eq 'ARRAY' ) {
            foreach my $e (@$entries) {
                next unless ref $e && $e->{title} =~ qr{Missing.*answer}i;

                $msg .= $e->{summary} if $e->{summary};

                if ( ref $e->{detail} ) {
                    my $d = $e->{detail};

                    if ( ref $d->{remediations} ) {
                        foreach my $remed ( $d->{remediations}->@* ) {
                            next unless $remed->{type} && $remed->{type} eq 'command';
                            next unless ref $remed->{context};
                            my @hint = $remed->{context}->@*;
                            next unless scalar @hint;
                            $hint[0] = q[/usr/bin/leapp] if $hint[0] && $hint[0] eq 'leapp';
                            my $cmd = join( ' ', @hint );

                            $msg .= "\n\n";
                            $msg .= <<"EOS";
Consider running this command:

    $cmd
EOS
                        }
                    }

                }

            }
        }
    }

    if ( -e LEAPP_REPORT_TXT ) {
        $msg .= qq[\nYou can read the full leapp report at: ] . LEAPP_REPORT_TXT;
    }

    die qq[$msg\n];
    return;
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
