package Elevate::StageFile;

=encoding utf-8

=head1 NAME

Elevate::StageFile

Library to get/set values in the stage file

=cut

use cPstrict;

use Cpanel::JSON ();

use File::Copy  ();
use Hash::Merge ();

use Log::Log4perl qw(:easy);

use constant ELEVATE_STAGE_FILE   => '/var/cpanel/elevate';
use constant ELEVATE_SUCCESS_FILE => '/var/cpanel/version/elevate';

sub create_success_file () {
    File::Copy::cp( ELEVATE_STAGE_FILE, ELEVATE_SUCCESS_FILE );
    return;
}

sub read_stage_file ( $k = undef, $default = {} ) {
    my $stage_info = Elevate::StageFile::_read_stage_file() // {};

    return $stage_info->{$k} // $default if defined $k;
    return $stage_info;
}

sub remove_from_stage_file ($key) {
    return unless length $key;

    my $stage = Elevate::StageFile::read_stage_file();

    my @list = split( qr/\./, $key );
    return unless scalar @list;

    my $to_delete = pop @list;

    my $h = $stage;
    while ( my $k = shift @list ) {
        $h = $h->{$k};
        last unless ref $h;
    }

    return if scalar @list;
    return unless exists $h->{$to_delete};

    delete $h->{$to_delete};

    return Elevate::StageFile::_save_stage_file($stage);
}

sub remove_stage_file () {
    unlink ELEVATE_STAGE_FILE;
    return;
}

sub update_stage_file ($data) {

    die q[Need a hash] unless ref $data eq 'HASH';

    my $current = Elevate::StageFile::read_stage_file();
    my $merged  = Hash::Merge::merge( $data, $current );

    return Elevate::StageFile::_save_stage_file($merged);
}

sub _read_stage_file () {
    return eval { Cpanel::JSON::LoadFile(ELEVATE_STAGE_FILE) };
}

sub _save_stage_file ($stash) {
    open( my $fh, '>', ELEVATE_STAGE_FILE ) or LOGDIE( "Failed to open " . ELEVATE_STAGE_FILE . ": $!" );
    print {$fh} Cpanel::JSON::pretty_canonical_dump($stash);
    close $fh;

    return 1;
}

1;
