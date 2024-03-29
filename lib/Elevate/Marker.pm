package Elevate::Marker;

=encoding utf-8

=head1 NAME

Elevate::Marker

This library provides logic to add information about the elevate process to the
stage file

=cut

use cPstrict;

use POSIX ();

use Cpanel::LoadFile      ();
use Cpanel::MD5           ();
use Cpanel::Version::Tiny ();

use Elevate::StageFile ();

use Log::Log4perl qw(:easy);

sub startup ( $sum = undef ) {

    $sum //= Cpanel::MD5::getmd5sum($0);
    chomp($sum);
    _write_debug_line($sum);

    Elevate::StageFile::update_stage_file(
        {
            '_elevate_process' => {
                script_md5            => $sum,
                cpanel_build          => $Cpanel::Version::Tiny::VERSION_BUILD,
                started_at            => _bq_now(),
                redhat_release_pre    => _read_redhat_release(),
                elevate_version_start => cpev::VERSION(),
            }
        }
    );

    return;
}

sub success () {

    Elevate::StageFile::update_stage_file(
        {
            '_elevate_process' => {
                finished_at            => _bq_now(),
                redhat_release_post    => _read_redhat_release(),
                elevate_version_finish => cpev::VERSION(),
            }
        }
    );

    return;
}

sub _bq_now () {
    return POSIX::strftime( '%FT%T', gmtime );
}

sub _read_redhat_release() {
    my ($first_line) = split( "\n", Cpanel::LoadFile::loadfile('/etc/redhat-release') // '' );

    return $first_line;
}

sub _write_debug_line ($sum) {
    DEBUG( sprintf( "Running $0 (%s/%s)", -s $0, $sum ) );
    return;
}

1;
