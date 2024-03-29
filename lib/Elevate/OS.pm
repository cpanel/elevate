package Elevate::OS;

=encoding utf-8

=head1 NAME

Elevate::OS

Abstract interface to the OS to obviate the need for if-this-os-do-this-elsif-elsif-else tech debt

=cut

use cPstrict;

use Carp ();

use Log::Log4perl qw(:easy);

use constant SUPPORTED_DISTROS => (
    'CentOS 7',
    'CloudLinux 7',
);

our $OS;

sub factory {
    my $distro_with_version = cpev::read_stage_file( 'upgrade_from', '' );

    my $distro;
    my $major;
    if ( !$distro_with_version ) {
        $distro              = Cpanel::OS::distro();
        $distro              = 'CentOS'     if $distro eq 'centos';
        $distro              = 'CloudLinux' if $distro eq 'cloudlinux';
        $major               = Cpanel::OS::major();
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
        'available_upgrade_paths',            # This returns a list of possible upgrade paths for the OS
        'default_upgrade_to',                 # This is the default OS that the current OS should upgrade to (i.e. CL7->CL8, C7->A8)
        'disable_mysql_yum_repos',            # This is a list of mysql repo files to disable
        'ea_alias',                           # This is the value for the --target-os flag used when backing up an EA4 profile
        'elevate_rpm_url',                    # This is the URL used to install the leapp RPM/repo
        'leapp_repo_prod',                    # This is the repo name for the production repo.
        'leapp_repo_beta',                    # This is the repo name for the beta repo. The OS might not provide a beta repo in which case it'll be blank.
        'is_experimental',                    # This is used to determine if the OS is experimental or not
        'is_supported',                       # This is used to determine if the OS is supported or not
        'leapp_can_handle_epel',              # This is used to determine if we can skip removing the EPEL repo pre_leapp or not
        'leapp_can_handle_imunify',           # This is used to determine if we can skip the Imunify component or not
        'leapp_can_handle_kernelcare',        # This is used to determine if we can skip the kernelcare component or not
        'leapp_can_handle_python36',          # This is used to determine if we can skip the python36 blocker or not
        'leapp_data_pkg',                     # This is used to determine which leapp data package to install
        'leapp_flag',                         # This is used to determine if we need to pass any flags to the leapp script or not
        'name',                               # This is the name of the OS we are upgrading from (i.e. CentOS7, or CloudLinux7)
        'pretty_name',                        # This is the pretty name of the OS we are upgrading from (i.e. 'CentOS 7')
        'provides_mysql_governor',            # This is used to determine if the OS provides the governor-mysql package
        'should_check_cloudlinux_license',    # This is used to determine if we should check the cloudlinux license
        'vetted_mysql_yum_repo_ids',          # This is a list of known mysql yum repo ids
        'vetted_yum_repo',                    # This is a list of known yum repos that we do not block on
    );
}

sub supported_methods {
    return sort keys %methods;
}

our $AUTOLOAD;

sub AUTOLOAD {
    my $sub = $AUTOLOAD;
    $sub =~ s/.*:://;

    exists $methods{$sub} or Carp::Croak("$sub is not a supported data variable for Elevate::OS");

    my $i   = instance();
    my $can = $i->can($sub) or Carp::Croak( ref($i) . " does not implement $sub" );
    return $can->( $i, @_ );
}

sub DESTROY { }    # This is a must for autoload modules

=head1 can_upgrade_to

This returns true or false depending on whether the current OS
is able to upgrade to the requested OS or not.

=cut

sub can_upgrade_to ($flavor) {
    return grep { $_ eq $flavor } Elevate::OS::available_upgrade_paths();
}

=head1 upgrade_to

This is the name of the OS we are upgrading to.  Data is stored
within the stages file.

=cut

sub upgrade_to () {
    my $default = Elevate::OS::default_upgrade_to();
    return cpev::read_stage_file( 'upgrade_to', $default );
}

sub clear_cache () {
    undef $OS unless $INC{'Test/Elevate.pm'};
    cpev::remove_from_stage_file('upgrade_from');
    return;
}

sub _set_cache () {
    cpev::update_stage_file( { upgrade_from => Elevate::OS::name() } );
    return;
}

1;
