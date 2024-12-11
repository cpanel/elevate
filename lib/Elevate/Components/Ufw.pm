package Elevate::Components::Ufw;

=encoding utf-8

=head1 NAME

Elevate::Components::Ufw

=head2 check

noop

=head2 pre_distro_upgrade

Open port 1022 for upgrades using do-release-upgrade

=head2 post_distro_upgrade

Close port 1022 for upgrades using do-release-upgrade

=cut

use cPstrict;

use Elevate::OS        ();
use Elevate::StageFile ();

use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

use constant UFW => '/usr/sbin/ufw';

sub pre_distro_upgrade ($self) {
    return if $self->upgrade_distro_manually();    # skip when --upgrade-distro-manually is provided
    return unless Elevate::OS::needs_do_release_upgrade();

    if ( !-x UFW ) {
        my $ufw = UFW;
        WARN( <<~"EOS" );
        '$ufw' is either missing or not executable on this server. Unable to
        ensure that port 1022 is open as a secondary ssh option for
        do-release-upgrade.
        EOS

        return;
    }

    my $current_status = $self->ssystem_capture_output( UFW, 'status' );
    my $is_active      = grep { $_ =~ m/^Status:\sactive$/ } @{ $current_status->{stdout} };
    my $is_open        = grep { $_ =~ m{^1022/tcp.*ALLOW.*Anywhere} } @{ $current_status->{stdout} };

    my $data = {
        is_active => $is_active,
        is_open   => $is_open,
    };

    Elevate::StageFile::update_stage_file( { ufw => $data } );

    return if $is_active && $is_open;

    $self->ssystem_and_die( UFW, 'allow', '1022/tcp' );

    $is_active ? $self->ssystem_and_die( UFW, 'reload' ) : $self->ssystem_and_die( UFW, '--force', 'enable' );

    return;
}

sub post_distro_upgrade ($self) {
    my $ufw_data = Elevate::StageFile::read_stage_file( 'ufw', '' );

    return unless ref $ufw_data && ref $ufw_data eq 'HASH';

    return if $ufw_data->{is_active} && $ufw_data->{is_open};

    $self->ssystem_and_die( UFW, 'delete', 'allow', '1022/tcp' );

    return if $ufw_data->{is_active};

    $self->ssystem_and_die( UFW, 'disable' );

    return;
}

1;
