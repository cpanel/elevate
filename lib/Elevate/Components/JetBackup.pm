package Elevate::Components::JetBackup;

=encoding utf-8

=head1 NAME

Elevate::Components::JetBackup

Capture and reinstall JetBackup.

=cut

use cPstrict;

use Cpanel::Pkgr       ();
use Elevate::Constants ();

use Cwd           ();
use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

sub pre_leapp ($self) {

    cpev::remove_from_stage_file('reinstall.jetbackup');

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

    cpev::update_stage_file( { 'reinstall' => { 'jetbackup' => $data } } );

    # Remove this package because leapp will remove it as it depends on libzip.so.2 which isn't available in 8.
    $self->ssystem(qw{/usr/bin/rpm -e --nodeps jetphp81-zip});

    return;
}

sub post_leapp ($self) {

    my $data = cpev::read_stage_file('reinstall')->{'jetbackup'};
    return unless ref $data && ref $data->{packages};

    INFO("Re-installing jetbackup.");

    my $tier     = $data->{tier};
    my @packages = $data->{packages}->@*;

    $self->ssystem( qw{/usr/bin/yum -y install --enablerepo=jetapps}, "--enablerepo=$tier", 'jetphp81-zip' );
    $self->ssystem( qw{/usr/bin/yum -y update --enablerepo=jetapps},  "--enablerepo=$tier", @packages );
    if ( $self->restore_rpmsave('/usr/local/jetapps/etc/.mongod.auth') ) {
        $self->ssystem(qw{/usr/bin/systemctl restart jetmongod});
        $self->ssystem(qw{/usr/bin/systemctl restart jetbackup5d});
    }

    return;
}

1;
