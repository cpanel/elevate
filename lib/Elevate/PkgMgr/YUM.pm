package Elevate::PkgMgr::YUM;

=encoding utf-8

=head1 NAME

Elevate::PkgMgr::YUM

Logic wrapping the RHEL based package managers

=cut

use cPstrict;

use Cpanel::OS ();

use Elevate::OS ();

use Log::Log4perl qw(:easy);

use parent 'Elevate::PkgMgr::Base';

our $rpm = '/usr/bin/rpm';

sub name ($self) {
    return Elevate::OS::package_manager();
}

sub _pkgmgr ($self) {
    return '/usr/bin/' . Cpanel::OS::package_manager();
}

sub get_config_files ( $self, $pkgs ) {

    my %config_files;
    foreach my $pkg (@$pkgs) {

        my $out = $self->ssystem_capture_output( $rpm, '-qc', $pkg ) || {};

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

sub _get_config_file_suffix ($self) {
    return '.rpmsave';
}

sub remove_no_dependencies_and_justdb ( $self, $pkg ) {
    $self->ssystem( $rpm, '-e', '--nodeps', '--justdb', $pkg );
    return;
}

sub remove_no_dependencies_or_scripts_and_justdb ( $self, $pkg ) {
    $self->ssystem( $rpm, '-e', '--nodeps', '--noscripts', '--justdb', $pkg );
    return;
}

sub force_upgrade_pkg ( $self, $pkg ) {
    my $err = $self->ssystem( $rpm, '-Uv', '--force', $pkg );
    return $err;
}

sub remove ( $self, @pkgs ) {
    return unless scalar @pkgs;

    my $pkgmgr = $self->_pkgmgr();

    $self->ssystem_and_die( $pkgmgr, '-y', 'remove', @pkgs );

    return;
}

sub clean_all ($self) {
    my $pkgmgr = $self->_pkgmgr();

    my $out = $self->ssystem_capture_output( $pkgmgr, 'clean', 'all' );

    return $out;
}

sub install_pkg_via_url ( $self, $pkg_url ) {
    my $pkgmgr = $self->_pkgmgr();

    $self->ssystem_and_die( $pkgmgr, '-y', 'install', $pkg_url );

    return;
}

sub install_with_options ( $self, $options, $pkgs ) {
    return unless scalar @$options;
    return unless scalar @$pkgs;

    my $pkgmgr = $self->_pkgmgr();

    # i.e. /usr/bin/yum -y install --enablerepo=jetapps --enablerepo=jetapps-stable jetphp81-zip
    $self->ssystem_and_die( $pkgmgr, '-y', 'install', @$options, @$pkgs );

    return;
}

sub install ( $self, @pkgs ) {
    return unless scalar @pkgs;

    my $pkgmgr = $self->_pkgmgr();

    $self->ssystem_and_die( $pkgmgr, '-y', 'install', @pkgs );

    return;
}

sub reinstall ( $self, @pkgs ) {
    return unless scalar @pkgs;

    my $pkgmgr = $self->_pkgmgr();

    $self->ssystem_and_die( $pkgmgr, '-y', 'reinstall', @pkgs );

    return;
}

sub repolist_all ($self) {
    return $self->repolist("all");
}

sub repolist_enabled ($self) {
    return $self->repolist("enabled");
}

sub repolist ( $self, @options ) {
    my $pkgmgr = $self->_pkgmgr();

    my $out   = $self->ssystem_hide_and_capture_output( $pkgmgr, '-q', 'repolist', @options );
    my @lines = @{ $out->{stdout} };

    # The first line is just header info
    shift @lines;

    my @repos;
    foreach my $line (@lines) {
        my $repo = ( split( '\s+', $line ) )[0];

        push @repos, $repo;
    }

    return @repos;
}

# No cache here since this is currently only called one time from a blocker
# Consider adding a cache if we ever call it anywhere else
sub get_extra_packages ($self) {
    my $pkgmgr = $self->_pkgmgr();

    # From the yum man page
    # yum list extras [glob_exp1] [...]
    #     List the packages installed on the system that are not available
    #     in any yum repository listed in the config file.
    my $out   = $self->ssystem_hide_and_capture_output( $pkgmgr, 'list', 'extras' );
    my @lines = @{ $out->{stdout} };
    while ( my $line = shift @lines ) {
        last if $line && $line =~ m/^Extra Packages/;
    }

    my @extra_packages;
    while ( my $line = shift @lines ) {
        chomp $line;
        my ( $package, $version, $repo ) = split( qr{\s+}, $line );

        if ( !length $version ) {
            my $extra_line = shift @lines;
            chomp $extra_line;
            $extra_line =~ s/^\s+//;
            ( $version, $repo ) = split( ' ', $extra_line );
        }
        if ( !length $repo ) {
            $repo = shift @lines;
            chomp $repo;
            $repo =~ s/\s+//g;
        }
        length $repo or next;    # We screwed up the parse. move on.

        # We only care about installed packages not associated with repos here
        $repo eq 'installed' or next;

        $package =~ s/\.(noarch|x86_64)$//;
        my $arch = $1 // '?';

        push @extra_packages, { package => $package, version => $version, arch => $arch };
    }

    return @extra_packages;
}

sub config_manager_enable ( $self, $repo ) {
    my $pkgmgr = $self->_pkgmgr();

    $self->ssystem( $pkgmgr, 'config-manager', '--enable', $repo );

    return;
}

sub update ($self) {
    my $pkgmgr = $self->_pkgmgr();

    $self->ssystem_and_die( $pkgmgr, '-y', 'update' );

    return;
}

sub update_with_options ( $self, $options, $pkgs ) {
    return unless scalar @$options;
    return unless scalar @$pkgs;

    my $pkgmgr = $self->_pkgmgr();

    # i.e. /usr/bin/yum -y update --enablerepo=jetapps --enablerepo=jetapps-stable @packages
    $self->ssystem_and_die( $pkgmgr, '-y', 'update', @$options, @$pkgs );

    return;
}

sub update_allow_erasing ( $self, @additional_args ) {
    my $pkgmgr = $self->_pkgmgr();

    my @args = (
        '-y',
        '--allowerasing',
    );

    push @args, @additional_args;
    $self->ssystem_and_die( $pkgmgr, @args, 'update' );
    return;
}

sub makecache ($self) {
    my $pkgmgr = $self->_pkgmgr();

    my $out    = $self->ssystem_capture_output( $pkgmgr, 'makecache' );
    my $stderr = join "\n", @{ $out->{stderr} };
    return $stderr;
}

my $pkg_list_cache;

sub pkg_list ( $self, $invalidate_cache = 0 ) {
    return $pkg_list_cache if !$invalidate_cache && $pkg_list_cache;

    my $pkgmgr = $self->_pkgmgr();

    my @lines = split "\n", Cpanel::SafeRun::Errors::saferunnoerror( $pkgmgr, 'list', 'installed' );
    while ( my $line = shift @lines ) {
        last if $line && $line =~ m/^Installed Packages/;
    }

    my %repos;
    while ( my $line = shift @lines ) {
        chomp $line;
        my ( $package, $version, $repo ) = split( qr{\s+}, $line );

        if ( !length $version ) {
            my $extra_line = shift @lines;
            chomp $extra_line;
            $extra_line =~ s/^\s+//;
            ( $version, $repo ) = split( ' ', $extra_line );
        }
        if ( !length $repo ) {
            $repo = shift @lines;
            chomp $repo;
            $repo =~ s/\s+//g;
        }
        length $repo or next;    # We screwed up the parse. move on.

        $repo =~ s/^\@// or next;
        $repos{$repo} ||= [];
        next if $repo eq 'installed';    # Not installed from a repo.

        $package =~ s/\.(noarch|x86_64)$//;
        my $arch = $1 // '?';
        push $repos{$repo}->@*, { 'package' => $package, 'version' => $version, arch => $arch };
    }

    return $pkg_list_cache = \%repos;
}

sub get_installed_pkgs_in_repo ( $self, @pkg_list ) {

    my @installed_pkgs;
    my $installed = $self->pkg_list();

    # Regex for repos.
    if ( ref $pkg_list[0] eq 'Regexp' ) {
        scalar @pkg_list == 1 or Carp::confess("too many args");
        my $regex = shift @pkg_list;

        @pkg_list = grep { $_ =~ $regex } keys %$installed;
    }

    foreach my $repo (@pkg_list) {
        next unless ref $installed->{$repo};
        next unless scalar $installed->{$repo}->@*;
        push @installed_pkgs, map { $_->{'package'} } $installed->{$repo}->@*;
    }

    return @installed_pkgs;
}

sub remove_pkgs_from_repos ( $self, @pkg_list ) {
    my @to_remove = $self->get_installed_pkgs_in_repo(@pkg_list);

    return unless @to_remove;

    INFO( "Removing packages for " . join( ", ", @pkg_list ) );

    $self->remove(@to_remove);

    return;
}

1;
