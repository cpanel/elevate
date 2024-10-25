package Elevate::PkgUtility::RPM;

=encoding utf-8

=head1 NAME

Elevate::PkgUtility::RPM

Logic wrapping the 'rpm' system binary

=cut

use cPstrict;

use File::Copy ();

use Log::Log4perl qw(:easy);

use parent 'Elevate::PkgUtility::Base';

our $rpm = '/usr/bin/rpm';

sub name ($self) {
    return 'RPM';
}

sub get_config_files_for_pkg_prefix ( $self, $prefix ) {

    my @installed_rpms = $self->get_installed_rpms(q[%{NAME}\n]);
    my @ea_rpms        = grep { $_ =~ qr/^\Q$prefix\E/ } @installed_rpms;
    my $config_files   = $self->get_config_files( \@ea_rpms );

    return $config_files;
}

sub get_config_files ( $self, $pkgs ) {

    my %config_files;
    foreach my $pkg (@$pkgs) {

        my $out = $self->cpev->ssystem_capture_output( $rpm, '-qc', $pkg ) || {};

        if ( $out->{status} != 0 ) {

            # warn and move on if rpm -qc fails
            WARN( <<~"EOS");
            Failed to retrieve config files for $pkg.  If you have custom config files for this pkg,
            then you will need to manually evaluate the configs and potentially move the rpmsave file back
            into place.
            EOS

            $config_files{$pkg} = [];
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

        File::Copy::mv( $backup_file, $file ) or WARN("Unable to restore config file $backup_file: $!");
    }

    return;
}

sub remove_no_dependencies ( $self, $pkg ) {
    $self->cpev->ssystem( $rpm, '-e', '--nodeps', $pkg );
    return;
}

sub remove_no_dependencies_and_justdb ( $self, $pkg ) {
    $self->cpev->ssystem( $rpm, '-e', '--nodeps', '--justdb', $pkg );
    return;
}

sub remove_no_dependencies_or_scripts_and_justdb ( $self, $pkg ) {
    $self->cpev->ssystem( $rpm, '-e', '--nodeps', '--noscripts', '--justdb', $pkg );
    return;
}

sub get_installed_rpms ( $self, $format = undef ) {
    my @args = qw{-qa};

    if ($format) {
        push @args, '--queryformat';
        push @args, $format;
    }

    my $out = $self->cpev->ssystem_capture_output( $rpm, @args );
    return @{ $out->{stdout} };
}

sub get_cpanel_arch_rpms ($self) {
    my @installed_rpms   = $self->get_installed_rpms();
    my @cpanel_arch_rpms = grep { $_ =~ m/^cpanel-.*\.x86_64$/ } @installed_rpms;
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
