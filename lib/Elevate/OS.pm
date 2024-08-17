package Elevate::OS;

=encoding utf-8

=head1 NAME

Elevate::OS

Abstract interface to the OS to obviate the need for if-this-os-do-this-elsif-elsif-else tech debt

=cut

use cPstrict;

use Carp ();

use Elevate::StageFile ();

use Log::Log4perl qw(:easy);

use constant SUPPORTED_DISTROS => (
    'CentOS 7',
    'CloudLinux 7',
);

our $OS;

sub factory {
    my $distro_with_version = Elevate::StageFile::read_stage_file( 'upgrade_from', '' );

    my $distro;
    my $major;
    if ( !$distro_with_version ) {
        $distro              = Cpanel::OS::distro();    ## no critic(Cpanel::CpanelOS)
        $distro              = 'CentOS'     if $distro eq 'centos';
        $distro              = 'CloudLinux' if $distro eq 'cloudlinux';
        $distro              = 'Ubuntu'     if $distro eq 'ubuntu';
        $major               = Cpanel::OS::major();     ## no critic(Cpanel::CpanelOS)
        $distro_with_version = $distro . $major;
    }

    my $class      = "Elevate::OS::" . $distro_with_version;
    my $class_path = "Elevate/OS/$distro_with_version.pm";

    # Ok if it dies since instance() should be the only thing calling this
    # Since this is a fat packed script, we only want to require the class in tests
    require $class_path unless $INC{$class_path};

    my $self = bless {}, $class;
    return $self;
}

sub instance {
    return $OS if $OS;

    $OS = eval { factory(); };

    if ( !$OS ) {

        # Ensure that we don't just fail silently if we hit this while tailing
        # the elevate log
        DEBUG("Unable to acquire Elevate::OS instance, dying") unless -t STDOUT;

        my $supported_distros = join( "\n", SUPPORTED_DISTROS() );
        die "This script is only designed to upgrade the following OSs:\n\n$supported_distros\n";
    }

    Elevate::OS::_set_cache();

    return $OS;
}

## NOTE: private methods (beginning with _) are NOT allowed in this list!
my %methods;

BEGIN {

    # The key specifies what the method that all platforms we support.
    # The value specifies how many args the method is designed to take.
    %methods = map { $_ => 0 } (
        ### General distro specific methods.
        'default_upgrade_to',                   # This is the default OS that the current OS should upgrade to (i.e. CL7->CL8, C7->A8)
        'disable_mysql_yum_repos',              # This is a list of mysql repo files to disable
        'ea_alias',                             # This is the value for the --target-os flag used when backing up an EA4 profile
        'elevate_rpm_url',                      # This is the URL used to install the leapp RPM/repo
        'leapp_repo_prod',                      # This is the repo name for the production repo.
        'leapp_repo_beta',                      # This is the repo name for the beta repo. The OS might not provide a beta repo in which case it'll be blank.
        'is_apt_based',                         # This is used to determine if the OS uses apt as its package manager
        'is_supported',                         # This is used to determine if the OS is supported or not
        'leapp_can_handle_epel',                # This is used to determine if we can skip removing the EPEL repo pre_leapp or not
        'leapp_can_handle_imunify',             # This is used to determine if we can skip the Imunify component or not
        'leapp_can_handle_kernelcare',          # This is used to determine if we can skip the kernelcare component or not
        'leapp_data_pkg',                       # This is used to determine which leapp data package to install
        'leapp_flag',                           # This is used to determine if we need to pass any flags to the leapp script or not
        'lts_supported',                        # This is the major cPanel version supported for this OS
        'name',                                 # This is the name of the OS we are upgrading from (i.e. CentOS7, or CloudLinux7)
        'needs_leapp',                          # This is used to determine if the OS requires the leapp utility to upgrade
        'pretty_name',                          # This is the pretty name of the OS we are upgrading from (i.e. 'CentOS 7')
        'provides_mysql_governor',              # This is used to determine if the OS provides the governor-mysql package
        'remove_els',                           # This is used to indicate if we are to remove ELS for this OS
        'should_check_cloudlinux_license',      # This is used to determine if we should check the cloudlinux license
        'skip_minor_version_check',             # Used to determine if we need to skip the minor version check for the OS
        'supported_cpanel_mysql_versions',      # Returns array of supported mysql versions for the OS we are upgrading to
        'supported_cpanel_nameserver_types',    # Returns array of supported nameserver types
        'supports_jetbackup',                   # This is used to determine if jetbackup is currently supported
        'supports_kernelcare',                  # This is used to determine if kernelcare is supported for this upgrade
        'supports_postgresql',                  # This is used to determine if postgresql is supported for this upgrade
        'upgrade_to_pretty_name',               # Returns the pretty name of the OS we are upgrading to (i.e. 'Ubuntu 22')
        'vetted_apt_lists',                     # This is a list of known apt lists that we do not block on
        'vetted_mysql_yum_repo_ids',            # This is a list of known mysql yum repo ids
        'vetted_yum_repo',                      # This is a list of known yum repos that we do not block on
    );
}

sub supported_methods {
    return sort keys %methods;                  ##no critic qw( ProhibitReturnSort ) - this will always be a list.
}

our $AUTOLOAD;

sub AUTOLOAD {    ## no critic(RequireArgUnpacking) - Most of the time we do not need to process args.
    my $sub = $AUTOLOAD;
    $sub =~ s/.*:://;

    exists $methods{$sub} or Carp::croak("$sub is not a supported data variable for Elevate::OS");

    my $i   = instance();
    my $can = $i->can($sub) or Carp::croak( ref($i) . " does not implement $sub" );
    return $can->( $i, @_ );
}

sub DESTROY { }    # This is a must for autoload modules

sub clear_cache () {
    undef $OS unless $INC{'Test/Elevate.pm'};
    Elevate::StageFile::remove_from_stage_file('upgrade_from');
    return;
}

sub _set_cache () {
    Elevate::StageFile::update_stage_file( { upgrade_from => Elevate::OS::name() } );
    return;
}

1;
