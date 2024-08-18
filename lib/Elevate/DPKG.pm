package Elevate::DPKG;

=encoding utf-8

=head1 NAME

Elevate::DPKG

Logic wrapping the 'dpkg' system binary

=cut

use cPstrict;

use File::Copy ();

use Cpanel::Pkgr ();

use Log::Log4perl qw(:easy);

use Simple::Accessor qw{
  cpev
};

use constant DPKG       => q[/usr/bin/dpkg];
use constant DPKG_QUERY => q[/usr/bin/dpkg-query];

use constant RESTORE_SUFFIX => q[.pre_elevate];

sub _build_cpev {
    die q[Missing cpev];
}

sub get_config_files_for_pkg_prefix ( $self, $prefix ) {

    my @installed_rpms = $self->get_installed_rpms();
    my @wanted_rpms    = grep { $_ =~ qr/^\Q$prefix\E/ } @installed_rpms;
    my $config_files   = $self->_get_config_files( \@wanted_rpms );

    return $config_files;
}

sub _get_config_files ( $self, $pkgs ) {

    my %config_files;
    foreach my $pkg (@$pkgs) {

        my $out = $self->cpev->ssystem_capture_output(
            DPKG_QUERY,
            q[--showformat='${Conffiles}\n'],
            '--show',
            $pkg
        );

        if ( $out->{status} != 0 ) {

            # warn and move on if the query fails
            WARN( <<~"EOS");
            Failed to retrieve config files for $pkg.  If you have custom config files for this pkg,
            then you will need to manually evaluate the configs and potentially move the rpmsave file back
            into place.
            EOS

        }
        else {

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
            }

            File::Copy::copy( $pkg, $pkg . RESTORE_SUFFIX );
            $config_files{$pkg} = \@pkg_config_files;
        }
    }

    return \%config_files;
}

sub get_installed_rpms ( $self, $format = undef ) {
    my $all_pkg_version = Cpanel::Pkgr::installed_packages();
    my @pkgs            = keys %$all_pkg_version;
    return @pkgs;
}

sub restore_config_files ( $self, @files ) {

    my $suffix = RESTORE_SUFFIX;

    foreach my $file (@files) {
        next unless length $file;

        my $backup_file = $file . $suffix;

        next unless -e $backup_file;

        File::Copy::move( $backup_file, $file ) or WARN("Unable to restore config file $backup_file: $!");
    }

    return;
}

sub remove_no_dependencies_and_justdb ( $self, $pkg ) {
    $self->cpev->ssystem( DPKG, '--remove', '--force-remove-reinstreq', '--force-depends', $pkg );
    return;
}

sub get_cpanel_arch_rpms ($self) {
    my @installed_rpms = $self->get_installed_rpms();

    # Ubuntu does not distiguish x86_64 from noarch the way RHEL does
    # so just remove anything with the 'cpanel-' prefix
    my @cpanel_arch_rpms = grep { $_ =~ m/^cpanel-/ } @installed_rpms;
    return @cpanel_arch_rpms;
}

sub remove_cpanel_arch_rpms ($self) {
    my @rpms_to_remove = $self->get_cpanel_arch_rpms();

    foreach my $rpm (@rpms_to_remove) {
        $self->remove_no_dependencies_and_justdb($rpm);
    }

    return;
}

1;
