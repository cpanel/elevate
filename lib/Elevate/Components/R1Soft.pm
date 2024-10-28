package Elevate::Components::R1Soft;

=encoding utf-8

=head1 NAME

Elevate::Components::R1Soft

=head2 check

noop

=head2 pre_distro_upgrade

Find out:
    Is the R1Soft agent installed?
    And, if so, is the R1Soft repo present and enabled?
And, if the agent is installed, go ahead and remove it.
(We'll need to reinstall it after the OS upgrade.)

=head2 post_distro_upgrade

If the agent had been installed:
    Re-install kernel-devel (needed by the agent install).
    Add the repo if it wasn't present.
    Enable the repo if it wasn't enabled.
    Re-install the agent.
    Disabled repo if it wasn't both present and enabled.

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::PkgMgr    ();
use Elevate::StageFile ();

use Cpanel::Pkgr ();

use File::Slurper ();
use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

sub pre_distro_upgrade ($self) {

    # Three pieces of information we wish to collect
    my $r1soft_agent_installed = 0;
    my $r1soft_repo_present    = 0;
    my $r1soft_repo_enabled    = 0;

    # We only care about the repo if the agent is installed
    if ( Cpanel::Pkgr::is_installed(Elevate::Constants::R1SOFT_MAIN_AGENT_PACKAGE) ) {
        $r1soft_agent_installed = 1;

        my @repo_list = Elevate::PkgMgr::repolist_enabled();

        if ( scalar grep { index( $_, Elevate::Constants::R1SOFT_REPO ) == 0 } @repo_list ) {
            $r1soft_repo_present = 1;
            $r1soft_repo_enabled = 1;
        }
        else {
            @repo_list = Elevate::PkgMgr::repolist_all();

            if ( scalar grep { index( $_, Elevate::Constants::R1SOFT_REPO ) == 0 } @repo_list ) {
                $r1soft_repo_present = 1;
            }
        }

        # Remove the agent packages; we'll need to reinstall them after the OS upgrade
        Elevate::PkgMgr::remove(Elevate::Constants::R1SOFT_AGENT_PACKAGES);
    }

    Elevate::StageFile::update_stage_file(
        {
            r1soft => {
                agent_installed => $r1soft_agent_installed,
                repo_present    => $r1soft_repo_present,
                repo_enabled    => $r1soft_repo_enabled,
            }
        }
    );

    return;
}

sub post_distro_upgrade ($self) {

    my $r1soft_info = Elevate::StageFile::read_stage_file('r1soft');

    # Nothing to do if the agent wasn't installed
    return unless $r1soft_info->{agent_installed};

    # We need kernel-devel for the agent install to work
    Elevate::PkgMgr::install('kernel-devel');

    # Ensure that the r1soft repo is present and enabled
    # if it was not that way to begin with
    if ( !$r1soft_info->{repo_present} ) {

        $self->_create_r1soft_repo();
    }
    else {
        $self->_enable_r1soft_repo() unless $r1soft_info->{repo_enabled};
    }

    # Now reinstall all the agent files
    Elevate::PkgMgr::install(Elevate::Constants::R1SOFT_AGENT_PACKAGES);

    if ( !$r1soft_info->{repo_present} || !$r1soft_info->{repo_enabled} ) {
        $self->_disable_r1soft_repo();
    }

    return;
}

# TODO: We will need to make this logic more generic if/when we add support for
#       r1soft on Ubuntu upgrades
sub _enable_r1soft_repo ($self) {
    return $self->_run_yum_config_manager( '--enable', Elevate::Constants::R1SOFT_REPO );
}

# TODO: We will need to make this logic more generic if/when we add support for
#       r1soft on Ubuntu upgrades
sub _disable_r1soft_repo ($self) {
    return $self->_run_yum_config_manager( '--disable', Elevate::Constants::R1SOFT_REPO );
}

# TODO: We will need to make this logic more generic if/when we add support for
#       r1soft on Ubuntu upgrades
sub _run_yum_config_manager ( $self, @args ) {
    my $yum_config = Cpanel::Binaries::path('yum-config-manager');

    my $err = $self->ssystem( $yum_config, @args );
    ERROR("Error running $yum_config: $err") if $err;

    return $err;
}

# TODO: We will need to make this logic more generic if/when we add support for
#       r1soft on Ubuntu upgrades
sub _create_r1soft_repo ($self) {

    my $yum_repo_contents = <<~"EOS";
    [r1soft]
    name=R1Soft Repository Server
    baseurl=https://repo.r1soft.com/yum/stable/\$basearch/
    enabled=1
    gpgcheck=0
    EOS

    if ( -e Elevate::Constants::R1SOFT_REPO_FILE ) {
        ERROR( "Cannot create R1Soft repo. File already exists: " . Elevate::Constants::R1SOFT_REPO_FILE );
        return;
    }

    File::Slurper::write_binary( Elevate::Constants::R1SOFT_REPO_FILE, $yum_repo_contents );

    chmod 0644, Elevate::Constants::R1SOFT_REPO_FILE;

    return;
}

1;
