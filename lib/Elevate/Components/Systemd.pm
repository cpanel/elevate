package Elevate::Components::Systemd;

=encoding utf-8

=head1 NAME

Elevate::Components::Systemd

=head2 check

noop

=head2 pre_distro_upgrade

* Put config file in place to tell systemd-resolved not to put a DNS listener in place
* Store the contents of /etc/resolv.conf in the stagefile if it is a file and has size

=head2 post_distro_upgrade

* Restore the contents of /etc/resolv.conf if it is a symlink
  which means that systemd or do-release-upgrade aggressively overwrote it

=cut

use cPstrict;

use File::Slurper ();

use Cpanel::SafeDir::MK ();

use Elevate::StageFile ();

use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

use constant RESOLVED_CONF_D => '/etc/systemd/resolved.conf.d';
use constant CPANEL_CONF     => RESOLVED_CONF_D . '/cpanel.conf';
use constant ETC_RESOLV_CONF => '/etc/resolv.conf';

sub pre_distro_upgrade ($self) {
    return if $self->upgrade_distro_manually();    # skip when --upgrade-distro-manually is provided

    $self->run_once('_add_systemd_resolved_config');
    $self->run_once('_store_etc_resolv_conf_contents');

    return;
}

sub post_distro_upgrade ($self) {

    $self->run_once('_restore_etc_resolv_conf_contents');

    return;
}

=head2 _add_systemd_resolved_config

Just do this no matter what.  It will not hurt anything if this file is in
place since ulc code also does this

=cut

sub _add_systemd_resolved_config ($self) {

    # No need to do this if the file is already in place
    return if -s CPANEL_CONF;

    Cpanel::SafeDir::MK::safemkdir( '/etc/systemd/resolved.conf.d', 0755 );
    File::Slurper::write_text( CPANEL_CONF, <<'EOF' );
[Resolve]
DNSStubListener=no
EOF

    chmod 0644, CPANEL_CONF;

    $self->ssystem( '/usr/bin/systemctl', 'daemon-reload' );
    $self->ssystem(qw{/usr/bin/systemctl restart systemd-resolved});

    return;
}

sub _store_etc_resolv_conf_contents ($self) {
    return unless -f ETC_RESOLV_CONF && -s _;

    my $resolv_conf = File::Slurper::read_binary(ETC_RESOLV_CONF);
    Elevate::StageFile::update_stage_file( { etc_resolv_conf => $resolv_conf } );

    return;
}

sub _restore_etc_resolv_conf_contents ($self) {
    return unless -l ETC_RESOLV_CONF;

    my $resolv_contents = Elevate::StageFile::read_stage_file( 'etc_resolv_conf', '' );
    return unless $resolv_contents;

    unlink ETC_RESOLV_CONF;
    File::Slurper::write_binary( ETC_RESOLV_CONF, $resolv_contents );
    chmod 0644, ETC_RESOLV_CONF;

    return;
}

1;
