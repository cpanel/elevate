package Elevate::Blockers::WHM;

=encoding utf-8

=head1 NAME

Elevate::Blockers::WHM

Blocker to check if cPanel&WHM state is compatible with the elevate process.

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::Notify    ();

use Cpanel::Version::Tiny ();
use Cpanel::Update::Tiers ();
use Cpanel::License       ();
use Cpanel::Pkgr          ();

use parent qw{Elevate::Blockers::Base};

use Log::Log4perl qw(:easy);

sub check ($self) {

    my $ok = 1;

    $ok = 0 unless $self->_blocker_is_missing_cpanel_whm;
    $ok = 0 unless $self->_blocker_is_invalid_cpanel_whm;
    $ok = 0 unless $self->_blocker_is_newer_than_lts;
    $ok = 0 unless $self->_blocker_cpanel_needs_license;
    $ok = 0 unless $self->_blocker_cpanel_needs_update;
    $ok = 0 unless $self->_blocker_is_sandbox;
    $ok = 0 unless $self->_blocker_is_calendar_installed;

    return $ok;
}

sub _blocker_is_missing_cpanel_whm ($self) {
    if ( !-x q[/usr/local/cpanel/cpanel] ) {
        return $self->has_blocker('This script is only designed to work with cPanel & WHM installs. cPanel & WHM do not appear to be present on your system.');
    }

    return 0;
}

sub _blocker_is_invalid_cpanel_whm ($self) {
    if ( !$Cpanel::Version::Tiny::major_version ) {
        return $self->has_blocker('Invalid cPanel & WHM major_version.');
    }

    return 0;
}

sub _blocker_is_newer_than_lts ($self) {
    if ( $Cpanel::Version::Tiny::major_version <= Elevate::Constants::MINIMUM_LTS_SUPPORTED - 2 ) {
        my $pretty_distro_name = $self->upgrade_to_pretty_name();
        return $self->has_blocker( sprintf( "This version %s does not support upgrades to %s. Please upgrade to cPanel version %s or better.", $Cpanel::Version::Tiny::VERSION_BUILD, $pretty_distro_name, Elevate::Constants::MINIMUM_LTS_SUPPORTED ) );
    }

    return 0;
}

sub _blocker_cpanel_needs_license ($self) {
    return 0 if Cpanel::License::is_licensed( skip_max_user_check => 1 );

    require Cpanel::DIp::MainIP;
    require Cpanel::NAT;

    my $localip  = Cpanel::DIp::MainIP::getmainip()     // '';
    my $publicip = Cpanel::NAT::get_public_ip($localip) // '';

    my $ip_msg = "";

    if ($publicip) {
        $ip_msg = <<~EOS;
        cPanel expects to find a license for the IP address $publicip.
        Verify whether that IP address is licensed using the following site:

        https://verify.cpanel.net/
        EOS
    }
    else {
        $ip_msg = <<~'EOS';
        Additionally, cPanel cannot determine which IP address is being used for licensing.
        EOS
    }

    return $self->has_blocker( <<~EOS );
    cPanel does not detect a valid license for itself on the system at this
    time. This could cause problems during the update.

    $ip_msg
    EOS
}

sub _blocker_cpanel_needs_update ($self) {
    if ( !$self->getopt('skip-cpanel-version-check') ) {
        my $tiers_obj = Cpanel::Update::Tiers->new( logger => Log::Log4perl->get_logger(__PACKAGE__) );
        if ( !grep { Cpanel::Version::Compare::compare( $Cpanel::Version::Tiny::VERSION_BUILD, '==', $_ ) } $tiers_obj->get_flattened_hash()->@{qw/edge current release stable lts/} ) {
            my $hint = '';
            $hint = q[hint: You can skip this check using --skip-cpanel-version-check] if $Cpanel::Version::Tiny::VERSION_BUILD =~ 9999;
            return $self->has_blocker( <<~"EOS" );
            This installation of cPanel ($Cpanel::Version::Tiny::VERSION_BUILD) does not appear to be up to date.
            Please upgrade cPanel to a most recent version. $hint
            EOS
        }
    }
    else {
        Elevate::Notify::warn_skip_version_check();
    }

    return 0;
}

sub _blocker_is_sandbox ($self) {
    if ( -e q[/var/cpanel/dev_sandbox] ) {
        return $self->has_blocker('Cannot elevate a sandbox...');
    }

    return 0;
}

sub _blocker_is_calendar_installed ($self) {
    if ( Cpanel::Pkgr::is_installed('cpanel-ccs-calendarserver') ) {
        return $self->has_blocker( <<~'EOS');
        You have the cPanel Calendar Server installed. Upgrades with this server in place are not supported.
        Removal of this server can lead to data loss.
        EOS
    }

    return 0;
}

1;
