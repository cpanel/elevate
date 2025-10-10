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
    'AlmaLinux 8',
    'AlmaLinux 9',
    'CentOS 7',
    'CloudLinux 7',
    'CloudLinux 8',
    'Ubuntu 20',
    'Ubuntu 22',
);

our $OS;

sub factory {
    my $distro_with_version = Elevate::StageFile::read_stage_file( 'upgrade_from', '' );

    my $distro;
    my $major;
    if ( !$distro_with_version ) {
        $distro              = Cpanel::OS::distro();    ## no critic(Cpanel::CpanelOS)
        $distro              = 'AlmaLinux'  if $distro eq 'almalinux';
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
        'archive_dir',                          # This is the dir to archive logs from successful elevations into
        'bootloader_config_method',             # This describes the canonical way to configure GRUB2
        'default_upgrade_to',                   # This is the default OS that the current OS should upgrade to (i.e. CL7->CL8, C7->A8)
        'disable_mysql_yum_repos',              # This is a list of mysql repo files to disable
        'ea_alias',                             # This is the value for the --target-os flag used when backing up an EA4 profile
        'el_package_regex',                     # This is the regex used to determine if old packages are still installed
        'elevate_rpm_url',                      # This is the URL used to install the leapp RPM/repo
        'expected_post_upgrade_major',          # The OS version we expect to upgrade to
        'has_crypto_policies',                  # This distro uses the crypto-policies framework.
        'has_imunify_ea_alias',                 # Whether CloudLinux provides and ea_alias to use when Imunify 360 provides hardened PHP
        'imunify_ea_alias',                     # Alias to use if Imunify 360 provides hardened PHP
        'is_apt_based',                         # This is used to determine if the OS uses apt as its package manager
        'is_experimental',                      # This is used to determine if upgrades for this OS are experimental
        'is_supported',                         # This is used to determine if the OS is supported or not
        'jetbackup_repo_rpm_url',               # This is the URL used to reinstall the jetbackup repo if required after elevation
        'leapp_can_handle_imunify',             # This is used to determine if we can skip the Imunify component or not
        'leapp_can_handle_kernelcare',          # This is used to determine if we can skip the kernelcare component or not
        'leapp_data_pkg',                       # This is used to determine which leapp data package to install
        'leapp_flag',                           # This is used to determine if we need to pass any flags to the leapp script or not
        'leapp_repo_beta',                      # This is the repo name for the beta repo. The OS might not provide a beta repo in which case it'll be blank.
        'leapp_repo_prod',                      # This is the repo name for the production repo.
        'lts_supported',                        # This is the major cPanel version supported for this OS
        'minimum_supported_cpanel_version',     # The version of cPanel that the target OS was introduced in
        'name',                                 # This is the name of the OS we are upgrading from (i.e. CentOS7, or CloudLinux7)
        'needs_crb',                            # This is used to determine if the OS requires the crb repo
        'needs_do_release_upgrade',             # This is used to determine if the OS requires the do-release-upgrade utility to upgrade
        'needs_epel',                           # This is used to determine if the OS requires the epel repo
        'needs_grub_enable_blscfg',             # This is a necessary config in /etc/dfault/grub in AlmaLinux 8 to ensure that it is fully managed by grub2
        'needs_leapp',                          # This is used to determine if the OS requires the leapp utility to upgrade
        'needs_network_manager',                # This is used to determine if the NetworkManager servoce needs to be enabled prior to running leapp
        'needs_powertools',                     # This is used to determine if the OS requires the powertools repo
        'needs_sha1_enabled',                   # This distro needs to be specially configured to support packages with SHA-1 signatures
        'needs_type_in_ifcfg',                  # This is used to determine if the OS requires the TYPE key in its ifcfg files (converts from network-scripts to NetworkManager)
        'needs_vdo',                            # AL8->9 inhibits without the vdo package installed (needed to perform authoritative checks for an obscure volume format)
        'network_scripts_are_supported',        # This is used to determine if the distro supports network scripts
        'original_os_major',                    # The initial starting OS major version
        'os_provides_sha1_module',              # The dsitro provides the SHA-1 signatures module to support packages using that signature
        'package_manager',                      # This is the package manager that the OS uses.  i.e. RPM
        'pkgmgr_lib_path',                      # The path to the package manager's database directory
        'pretty_name',                          # This is the pretty name of the OS we are upgrading from (i.e. 'CentOS 7')
        'provides_mysql_governor',              # This is used to determine if the OS provides the governor-mysql package
        'remove_els',                           # This is used to indicate if we are to remove ELS for this OS
        'set_update_tier_to_release',           # This is used to determine if we should set the update tier to release
        'should_archive_elevate_files',         # This is used to determine if existing elevate logs should be archived
        'should_check_cloudlinux_license',      # This is used to determine if we should check the cloudlinux license
        'skip_minor_version_check',             # Used to determine if we need to skip the minor version check for the OS
        'supported_cpanel_mysql_versions',      # Returns array of supported mysql versions for the OS we are upgrading to
        'supported_cpanel_nameserver_types',    # Returns array of supported nameserver types
        'supports_cpaddons',                    # This is used to determine if cpaddons is currently supported
        'supports_jetbackup',                   # This is used to determine if jetbackup is currently supported
        'supports_kernelcare',                  # This is used to determine if kernelcare is currently supported for this upgrade
        'supports_named_tiers',                 # This is used to determine if the OS is eligible to upgrade on any named tier (RELEASE, STABLE, etc)
        'supports_postgresql',                  # This is used to determine if postgresql is supported for this upgrade
        'upgrade_to_pretty_name',               # Returns the pretty name of the OS we are upgrading to (i.e. 'Ubuntu 22')
        'vetted_apt_lists',                     # This is a list of known apt lists that we do not block on
        'vetted_mysql_yum_repo_ids',            # This is a list of known mysql yum repo ids
        'vetted_yum_repo',                      # This is a list of known yum repos that we do not block on
        'yum_conf_needs_plugins',               # The yum configuration needs plugins=1 set in order for yum to work correctly
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
