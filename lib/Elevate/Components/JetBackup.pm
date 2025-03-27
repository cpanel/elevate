package Elevate::Components::JetBackup;

=encoding utf-8

=head1 NAME

Elevate::Components::JetBackup

=head2 check

If JetBackup is installed, ensure that it is a supported version

=head2 pre_distro_upgrade

Capture list of JetBackup packages to reinstall and remove a package that is not
supported on 8

=head2 post_distro_upgrade

Reinstall JetBackup packages

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::OS        ();
use Elevate::PkgMgr    ();
use Elevate::StageFile ();

use Cpanel::Pkgr ();

use Cwd           ();
use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

sub pre_distro_upgrade ($self) {

    Elevate::StageFile::remove_from_stage_file('reinstall.jetbackup');

    return unless Cpanel::Pkgr::is_installed('jetbackup5-cpanel');

    my $repos = Elevate::PkgMgr::pkg_list();
    my $jetbackup_tier =
        $repos->{'jetapps-stable'} ? 'jetapps-stable'
      : $repos->{'jetapps-edge'}   ? 'jetapps-edge'
      : $repos->{'jetapps-beta'}   ? 'jetapps-beta'
      :                              'jetapps-stable';    # Just give up and choose stable if you can't guess.
    INFO("Jetbackup tier '$jetbackup_tier' detected. Not removing jetbackup. Will re-install it after elevate.");
    if ( ref Elevate::PkgMgr::instance() eq 'Elevate::PkgMgr::APT' ) {

        # We need to enable that repo if possible and run apt update so that we can fetch the pkglist for it
        if ( -f "/etc/apt/sources.list.d/$jetbackup_tier.list.disabled" ) {
            rename( "/etc/apt/sources.list.d/$jetbackup_tier.list.disabled", "/etc/apt/sources.list.d/$jetbackup_tier.list" ) || WARN("Couldn't enable repository for $jetbackup_tier: $!");
        }
    }
    my @reinstall = Elevate::PkgMgr::get_installed_pkgs_in_repo(qw/jetapps jetapps-stable jetapps-beta jetapps-edge/);

    # Force certain things onto the list no matter what
    push @reinstall, 'jetbackup5-cpanel' if !grep { $_ eq 'jetbackup5-cpanel' } @reinstall;
    unshift @reinstall, $jetbackup_tier;

    # Remove this package because leapp will remove it as it depends on libzip.so.2 which isn't available in 8.
    if ( Elevate::OS::needs_leapp() && Cpanel::Pkgr::is_installed('jetphp81-zip') ) {
        Elevate::PkgMgr::remove_no_dependencies('jetphp81-zip');
        push @reinstall, 'jetphp81-zip' if !grep { $_ eq 'jetphp81-zip' } @reinstall;
    }

    my $data = {
        tier     => $jetbackup_tier,
        packages => \@reinstall,
    };

    Elevate::StageFile::update_stage_file( { 'reinstall' => { 'jetbackup' => $data } } );

    return;
}

sub post_distro_upgrade ($self) {

    my $data = Elevate::StageFile::read_stage_file('reinstall')->{'jetbackup'};
    return unless ref $data && ref $data->{packages};

    INFO("Re-installing jetbackup.");

    if ( Elevate::OS::jetbackup_repo_rpm_url() ) {
        Elevate::PkgMgr::install_pkg_via_url( Elevate::OS::jetbackup_repo_rpm_url() );
    }

    my $tier     = $data->{tier};
    my @packages = $data->{packages}->@*;

    my $pkgmgr_options = [ '--enablerepo=jetapps', "--enablerepo=$tier" ];

    # Technically, this isn't possible on ubuntu, but we need it for cent.
    # It falls through to just update thankfully.
    Elevate::PkgMgr::update_with_options( $pkgmgr_options, \@packages );

    return;
}

sub check ($self) {

    $self->_blocker_jetbackup_is_supported();
    $self->_blocker_old_jetbackup;

    return;
}

# Support for JetBackup on AlmaLinux 8 is not yet available.
# We will add support for JetBackup on AlmaLinux 8 in a future version of ELevate.
# For now, we block to reduce scope for the initial release
sub _blocker_jetbackup_is_supported ($self) {
    return unless Cpanel::Pkgr::is_installed('jetbackup5-cpanel');
    return if Elevate::OS::supports_jetbackup();

    my $name = Elevate::OS::pretty_name();
    return $self->has_blocker( <<~"END" );
    ELevate does not currently support JetBackup for upgrades of $name.
    Support for JetBackup on $name will be added in a future version of ELevate.
    END
}

sub _blocker_old_jetbackup ($self) {

    return 0 unless $self->_use_jetbackup4_or_earlier();

    my $pretty_distro_name = Elevate::OS::upgrade_to_pretty_name();

    return $self->has_blocker( <<~"END" );
    $pretty_distro_name does not support JetBackup prior to version 5.
    Please upgrade JetBackup before elevate.
    END

}

sub _use_jetbackup4_or_earlier ($self) {
    return unless Cpanel::Pkgr::is_installed('jetbackup');
    my $v = Cpanel::Pkgr::get_package_version("jetbackup");

    if ( defined $v && $v =~ qr{^[1-4]\b} ) {
        WARN("JetBackup version $v currently installed.");
        return 1;
    }

    return;
}

1;
