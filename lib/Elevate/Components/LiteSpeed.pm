package Elevate::Components::LiteSpeed;

=encoding utf-8

=head1 NAME

Elevate::Components::LiteSpeed

Capture and reinstall LiteSpeed packages.

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::StageFile ();

use Cwd           ();
use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

sub pre_distro_upgrade ($self) {

    Elevate::StageFile::remove_from_stage_file('reinstall.litespeed');

    my $ls_cfg_dir = q[/usr/local/lsws/conf];
    return unless -d $ls_cfg_dir;

    INFO("LiteSpeed is installed");

    # check if the license is valid before updating
    $self->ssystem(qw{/usr/local/lsws/bin/lshttpd -V});
    my $has_valid_license = $? == 0 ? 1 : 0;

    my $data = {
        has_valid_license => $has_valid_license,
    };

    Elevate::StageFile::update_stage_file( { 'reinstall' => { 'litespeed' => $data } } );

    return;
}

sub post_distro_upgrade ($self) {

    my $data = Elevate::StageFile::read_stage_file('reinstall')->{'litespeed'};
    return unless ref $data;

    INFO("Checking LiteSpeed");

    # check the current license
    if ( $data->{has_valid_license} ) {
        $self->ssystem(qw{/usr/local/lsws/bin/lshttpd -V});
        ERROR("LiteSpeed license is not valid. Check /usr/local/lsws/conf/serial.no") if $? != 0;
    }

    $self->ssystem(qw{/usr/bin/systemctl restart lsws});

    return;
}

1;
