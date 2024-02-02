package Elevate::RPM;

=encoding utf-8

=head1 NAME

Elevate::RPM

Logic wrapping the 'rpm' system binary

=cut

use cPstrict;

use Log::Log4perl qw(:easy);

use Simple::Accessor qw{
  cpev
};

sub _build_cpev {
    die q[Missing cpev];
}

sub get_config_files_for_repo ( $self, $repo ) {

    my @installed    = cpev::get_installed_rpms_in_repo($repo);
    my $config_files = $self->_get_config_files( \@installed );

    return $config_files;
}

sub _get_config_files ( $self, $pkgs ) {

    my %config_files;
    foreach my $pkg (@$pkgs) {

        my $out = $self->cpev->ssystem_capture_output( '/usr/bin/rpm', '-qc', $pkg ) || {};

        if ( $out->{status} != 0 ) {

            # warn and move on if rpm -qc fails
            WARN( <<~"EOS");
            Failed to retrieve config files for $pkg.  If you have custom config files for this pkg,
            then you will need to manually evaluate the configs and potentially move the rpmsave file back
            into place.
            EOS

        }
        else {

            # rpm -qc will return absolute paths if the package has config files
            # In the event that package does not contain any files, it will return
            # "(contains no files)"
            # We need to filter anything that is not an absolute path out
            my @pkg_config_files = grep { $_ =~ m{^/} } @{ $out->{stdout} };

            $config_files{$pkg} = \@pkg_config_files;
        }
    }

    return \%config_files;
}

sub restore_config_files ( $self, @files ) {

    # %config and %config(noreplace) both get moved to '.rpmsave' when removing an RPM
    my $suffix = '.rpmsave';

    foreach my $file (@files) {
        next unless length $file;

        my $backup_file = $file . $suffix;

        next unless -e $backup_file;

        File::Copy::move( $backup_file, $file ) or WARN("Unable to restore config file $backup_file: $!");
    }

    return;
}

1;
