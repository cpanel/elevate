package Elevate::Components::PackageDupes;

=encoding utf-8

=head1 NAME

Elevate::Components::PackageDupes

=cut

use cPstrict;

use Digest::SHA ();

use Elevate::Constants  ();
use Elevate::PkgUtility ();

use Cpanel::SafeRun::Simple           ();
use Cpanel::Version::Compare::Package ();

use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

use constant { ALPHA => 0, DIGIT => 1 };

=head1 METHODS

=head2 pre_distro_upgrade

Detect if there are any duplicate packages using C<package-cleanup --dupes>.
If not, great. Otherwise, we need to remove the duplicates ourselves.

Since the tool explicitly does not guarantee that the duplicates will be listed
in any particular order, we need to sort the packages ourselves.

On the assumption that the newer package did not install correctly and is the
problem, we will remove it.  Use L<Cpanel::Version::Compare::Package> to figure
this out.

Note that there is a further assumption that there will only be two packages in
a duplicated set.  What happens if that is not the case? We have to remove all
but one, but which is the right choice to keep?  Oldest one? Second-newest one?
Or is the first assumption about the problem being during upgrade then wrong?
The working assumption will be to remove all but the second-newest.

Package removal is not only without dependencies and just with the DB, but we
also ignore scripts.

TODO: Is this phenomenon of duplicate packages exclusive to RPM systems? If so,
bail out early on Ubuntu when that support is added.  If not, refactor needed
to make it more distro-agnostic.

=cut

sub pre_distro_upgrade ($self) {

    INFO('Looking for duplicate system packages...');
    my %dupes = $self->_find_dupes();
    if ( scalar %dupes > 0 ) {

        INFO('Duplicates found.');
        if ( !-d Elevate::Constants::RPMDB_BACKUP_DIR ) {
            INFO('Backing up system package database. If there are problems upgrading packages, consider restoring this backup and resolving the duplicate packages manually.');
            if ( $self->_backup_rpmdb() ) {
                INFO( 'Active RPM database: ' . Elevate::Constants::RPMDB_DIR );
                INFO( 'Backup RPM database: ' . Elevate::Constants::RPMDB_BACKUP_DIR );
            }
            else {
                ERROR('The backup process did not produce a correct backup! ELevate will proceed with the next step in the upgrade process without attempting to correct the issue. If there are problems upgrading packages, resolve the duplicate packages manually.');
                return;
            }
        }

        my @packages_to_remove = $self->_select_packages_for_removal(%dupes);

        DEBUG( "The following packages are being removed from the system package database:\n" . join( "\n", @packages_to_remove ) );
        $self->_remove_packages(@packages_to_remove);
    }
    else {
        INFO('No duplicate packages found.');
    }

    return;
}

sub _find_dupes ($self) {
    my %dupes;
    my $output = Cpanel::SafeRun::Simple::saferunnoerror(qw( /usr/bin/package-cleanup --dupes ));

    foreach my $line ( split /\n/, $output ) {
        my ( $name, $version, $release, $arch ) = _parse_package($line);
        push $dupes{$name}->@*, { version => $version, release => $release, arch => $arch } if $name;
    }

    return %dupes;
}

sub _parse_package ($pkg) {
    return ( $pkg =~ m/^(.+)-(.+)-(.+)\.(.+)$/ );
}

# To ensure that the backup is absolutely correct, use the original as the backup, and then copy it back into place.
sub _backup_rpmdb ($self) {
    my ( $orig_dir, $backup_dir ) = ( Elevate::Constants::RPMDB_DIR, Elevate::Constants::RPMDB_BACKUP_DIR );
    rename $orig_dir, $backup_dir or LOGDIE("Failed to move $orig_dir to $backup_dir (reason: $!)");

    # Even if dircopy returns a truthy value, we can't trust it.
    File::Copy::Recursive::dircopy( $backup_dir, $orig_dir );
    if ( !_rpmdb_backup_is_good( $orig_dir, $backup_dir ) ) {
        restore_rpmdb_from_backup();
        return 0;
    }

    return 1;
}

sub _rpmdb_backup_is_good ( $orig_dir, $backup_dir ) {

    opendir( my $orig_dh,   $orig_dir )   or return 0;
    opendir( my $backup_dh, $backup_dir ) or return 0;

    my @orig_files   = sort grep { !/^\./ } readdir($orig_dh);
    my @backup_files = sort grep { !/^\./ } readdir($backup_dh);

    return 0 if scalar @orig_files != scalar @backup_files;

    while ( scalar @orig_files && scalar @backup_files ) {
        my ( $orig_file, $backup_file ) = ( shift(@orig_files), shift(@backup_files) );
        return 0 if $orig_file ne $backup_file;

        my ( $orig_digest, $backup_digest ) = map { Digest::SHA->new(256)->addfile($_)->hexdigest } ( "$orig_dir/$orig_file", "$backup_dir/$backup_file" );
        return 0 if !$orig_digest || !$backup_digest || $orig_digest ne $backup_digest;
    }

    return 1;
}

sub restore_rpmdb_from_backup () {

    # Absolutely DO NOT let anything interrupt us here, if we can help it:
    local $SIG{'HUP'}  = 'IGNORE';
    local $SIG{'TERM'} = 'IGNORE';
    local $SIG{'INT'}  = 'IGNORE';
    local $SIG{'QUIT'} = 'IGNORE';
    local $SIG{'USR1'} = 'IGNORE';
    local $SIG{'USR2'} = 'IGNORE';

    my ( $orig_dir, $backup_dir ) = ( Elevate::Constants::RPMDB_DIR, Elevate::Constants::RPMDB_BACKUP_DIR );

    File::Path::rmtree($orig_dir);
    rename $backup_dir, $orig_dir or LOGDIE("Failed to restore original RPM database to $orig_dir (reason: $!)! It is currently stored at $backup_dir.");

    return;
}

sub _select_packages_for_removal ( $self, %dupes ) {
    my @pkgs_for_removal;

    for my $pkg ( keys %dupes ) {
        my @sorted_versions = sort { Cpanel::Version::Compare::Package::version_cmp( $a->{version}, $b->{version} ) || Cpanel::Version::Compare::Package::version_cmp( $a->{release}, $b->{release} ) } $dupes{$pkg}->@*;

        # Keep second-newest package:
        splice @sorted_versions, -2, 1;

        # Reconstruct package strings and push to the list:
        push @pkgs_for_removal, sprintf( '%s-%s-%s.%s', $pkg, $_->@{qw( version release arch )} ) foreach @sorted_versions;
    }

    return @pkgs_for_removal;
}

sub _remove_packages ( $self, @packages ) {
    foreach my $pkg (@packages) {
        Elevate::PkgUtility::remove_no_dependencies_or_scripts_and_justdb($pkg);
    }
    return;
}

1;
