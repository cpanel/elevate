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

    my $repos = cpev::yum_list();
    my $jetbackup_tier =
        $repos->{'jetapps-stable'} ? 'jetapps-stable'
      : $repos->{'jetapps-edge'}   ? 'jetapps-edge'
      : $repos->{'jetapps-beta'}   ? 'jetapps-beta'
      :                              'jetapps-stable';    # Just give up and choose stable if you can't guess.
    INFO("Jetbackup tier '$jetbackup_tier' detected. Not removing jetbackup. Will re-install it after elevate.");
    my @reinstall = cpev::get_installed_rpms_in_repo(qw/jetapps jetapps-stable jetapps-beta jetapps-edge/);
    unshift @reinstall, $jetbackup_tier;

    my $data = {
        tier     => $jetbackup_tier,
        packages => \@reinstall,
    };

    Elevate::StageFile::update_stage_file( { 'reinstall' => { 'jetbackup' => $data } } );

    # Remove this package because leapp will remove it as it depends on libzip.so.2 which isn't available in 8.
    Elevate::PkgMgr::remove_no_dependencies('jetphp81-zip');

    return;
}

sub post_distro_upgrade ($self) {

    my $data = Elevate::StageFile::read_stage_file('reinstall')->{'jetbackup'};
    return unless ref $data && ref $data->{packages};

    INFO("Re-installing jetbackup.");

    my $tier     = $data->{tier};
    my @packages = $data->{packages}->@*;

    $self->ssystem( qw{/usr/bin/yum -y install --enablerepo=jetapps}, "--enablerepo=$tier", 'jetphp81-zip' );
    $self->ssystem( qw{/usr/bin/yum -y update --enablerepo=jetapps},  "--enablerepo=$tier", @packages );

    return;
}

sub check ($self) {

    return $self->_blocker_old_jetbackup;
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
