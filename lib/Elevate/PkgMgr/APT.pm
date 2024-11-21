package Elevate::PkgMgr::APT;

=encoding utf-8

=head1 NAME

Elevate::PkgMgr::APT

Logic wrapping the DEBIAN based package managers

=cut

use cPstrict;

use File::Copy ();

use Elevate::OS ();

use Log::Log4perl qw(:easy);

use parent 'Elevate::PkgMgr::Base';

use constant APT_NON_INTERACTIVE_ARGS => qw{
  -o Dpkg::Options::=--force-confdef
  -o Dpkg::Options::=--force-confold
};

our $apt_get    = '/usr/bin/apt-get';
our $apt_mark   = '/usr/bin/apt-mark';
our $dpkg       = '/usr/bin/dpkg';
our $dpkg_query = '/usr/bin/dpkg-query';

sub name ($self) {
    return Elevate::OS::package_manager();
}

sub get_config_files ( $self, $pkgs ) {

    my %config_files;
    foreach my $pkg (@$pkgs) {

        my $out = $self->ssystem_capture_output(
            $dpkg_query,
            q[--showformat=${Conffiles}\n],
            '--show',
            $pkg
        );

        if ( $out->{status} != 0 ) {

            # warn and move on if rpm -qc fails
            WARN( <<~"EOS");
            Failed to retrieve config files for $pkg.  If you have custom config files for this pkg,
            then you will need to manually evaluate the configs and potentially move the rpmsave file back
            into place.
            EOS

        }
        else {

            my $restore_suffix = $self->_get_config_file_suffix();

            # The query will return the absolute path of config file followed
            # by a space and the original md5sum of the file
            # If the package does not contain any files, it will return an
            # empty line
            my @pkg_config_files;
            foreach my $line ( @{ $out->{stdout} } ) {
                next if $line =~ m{^\s*$};
                $line =~ s/^\s+|\s+$//g;

                my ( $config_file, $md5sum ) = split qr/\s+/, $line;
                push @pkg_config_files, $config_file;

                File::Copy::cp( $config_file, $config_file . $restore_suffix );
            }

            $config_files{$pkg} = \@pkg_config_files;
        }
    }

    return \%config_files;
}

sub _get_config_file_suffix ($self) {
    return '.pre_elevate';
}

=head1 remove_no_dependencies_and_justdb

The RPM version of this just removes the packages from the rpmdb. It otherwise
does not touch the filesystem. Dpkg does not have a similar functionality so
we simply make this a noop for it. This is okay to do for Ubuntu upgrades using
ELevate since Ubuntu is more tolerant of this sort of thing in general and the
packages this is currently used for will be upgraded to the version built
for the newer version of Ubuntu anyway when upcp executes.

=cut

sub remove_no_dependencies_and_justdb ( $self, $pkg ) {
    return;
}

=head1 remove_no_dependencies_or_scripts_and_justdb

The RPM version of this just removes the packages from the rpmdb. It otherwise
does not touch the filesystem. Dpkg does not have a similar functionality so
we simply make this a noop for it. This is okay to do for Ubuntu upgrades using
ELevate since Ubuntu is more tolerant of this sort of thing in general and the
packages this is currently used for will be upgraded to the version built
for the newer version of Ubuntu anyway when upcp executes.

=cut

sub remove_no_dependencies_or_scripts_and_justdb ( $self, $pkg ) {
    return;
}

=head1 force_upgrade_pkg

This is currently unused during Ubuntu upgrades. There is no equivalent to what
the RPM verison is doing as far as I can tell so I am choosing to redirect this
to use update() instead.  This may need to be revisited if update() does not
serve our purposes.

=cut

sub force_upgrade_pkg ( $self, $pkg ) {
    return $self->update($pkg);
}

=head1 remove

Use purge instead of remove for apt to have similar behavior to yum/dnf

=cut

sub remove ( $self, @pkgs ) {
    return unless scalar @pkgs;

    my @apt_args = (
        '-y',
        APT_NON_INTERACTIVE_ARGS,
    );

    $self->ssystem_and_die( $apt_get, @apt_args, 'purge', @pkgs );

    return;
}

sub clean_all ($self) {
    my $out = $self->ssystem_capture_output( $apt_get, 'clean' );
    return $out;
}

=head1 install_with_options

Apt does not handle repos/PPAs the same way as yum and what we are currently
using this for is not needed with apt.  As such, this is just calling install
without the additional options

=cut

sub install_with_options ( $self, $options, $pkgs ) {
    return unless scalar @$pkgs;
    return $self->install(@$pkgs);
}

sub install ( $self, @pkgs ) {
    return unless scalar @pkgs;

    my @apt_args = (
        '-y',
        APT_NON_INTERACTIVE_ARGS,
    );

    $self->ssystem_and_die( $apt_get, @apt_args, 'install', @pkgs );

    return;
}

sub reinstall ( $self, @pkgs ) {
    return unless scalar @pkgs;

    my @apt_args = (
        '-y',
        APT_NON_INTERACTIVE_ARGS,
    );

    $self->ssystem_and_die( $apt_get, @apt_args, 'reinstall', @pkgs );

    return;
}

sub update ($self) {

    my @apt_args = (
        '-y',
        '--with-new-pkgs',
        APT_NON_INTERACTIVE_ARGS,
    );

    $self->ssystem_and_die( $apt_get, @apt_args, 'upgrade' );

    return;
}

=head1 update_with_options

Apt does not handle repos/PPAs the same way as yum and what we are currently
using this for is not needed with apt.  As such, this is just calling update
without the additional options

=cut

sub update_with_options ( $self, $options, $pkgs ) {
    return $self->update();
}

sub update_allow_erasing ( $self, @additional_args ) {
    $self->ssystem_and_die( $apt_get, '-y', 'autoremove', '--purge' );
    $self->update();
    return;
}

sub makecache ($self) {
    my $out    = $self->ssystem_capture_output( $apt_get, 'update' );
    my @errors = grep { $_ !~ m/apt does not have a stable CLI interface/ } @{ $out->{stderr} };
    my $stderr = join "\n", @errors;
    return $stderr;
}

sub showhold ($self) {
    my $out = $self->ssystem_capture_output( $apt_mark, 'showhold' );
    return $out;
}

=head1 pkg_list

APT does not have an equivalent to this but it is also not needed for debian upgrades.
As such, we just make it a noop where it returns an empty href

=cut

sub pkg_list ( $self, $invalidate_cache = 0 ) {
    return {};
}

=head1 remove_pkgs_from_repos

This is a noop for apt since it is not currently needed for debian based upgrades

=cut

sub remove_pkgs_from_repos ( $self, @pkg_list ) {
    return;
}

1;
