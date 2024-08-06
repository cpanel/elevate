package Elevate::EA4;

=encoding utf-8

=head1 NAME

Elevate::EA4

Logic to backup and restore EA4 profiles

=cut

use cPstrict;

use File::Temp ();

use Elevate::Constants ();
use Elevate::OS        ();
use Elevate::StageFile ();

use Cpanel::Config::Httpd   ();
use Cpanel::JSON            ();
use Cpanel::Pkgr            ();
use Cpanel::SafeRun::Simple ();

use Log::Log4perl qw(:easy);

use constant IMUNIFY_AGENT => Elevate::Constants::IMUNIFY_AGENT;

sub backup ( $check_mode = 0 ) {
    Elevate::EA4::_backup_ea4_profile($check_mode);
    Elevate::EA4::_backup_ea_addons();
    return;
}

sub _backup_ea4_profile ($check_mode) {

    my $use_ea4 = Cpanel::Config::Httpd::is_ea4() ? 1 : 0;

    Elevate::StageFile::remove_from_stage_file('ea4');
    Elevate::StageFile::update_stage_file( { ea4 => { enable => $use_ea4 } } );

    unless ($use_ea4) {
        WARN('Skipping EA4 backup. EA4 does not appear to be enabled on this system');
        return;
    }

    my $json_path = Elevate::EA4::_get_ea4_profile($check_mode);

    my $data = { profile => $json_path };

    # store dropped packages
    my $profile = eval { Cpanel::JSON::LoadFile($json_path) } // {};
    if ( ref $profile->{os_upgrade} && ref $profile->{os_upgrade}->{dropped_pkgs} ) {
        $data->{dropped_pkgs} = $profile->{os_upgrade}->{dropped_pkgs};
    }

    Elevate::StageFile::update_stage_file( { ea4 => $data } );

    return;
}

sub _imunify360_is_installed_and_provides_hardened_php () {
    return 0 unless -x IMUNIFY_AGENT;

    my $out          = Cpanel::SafeRun::Simple::saferunnoerror( IMUNIFY_AGENT, qw{version --json} );
    my $license_data = eval { Cpanel::JSON::Load($out) } // {};

    return 0 unless ref $license_data->{license};

    if ( $license_data->{'license'}->{'license_type'} eq 'imunify360' ) {

        my $output   = Cpanel::SafeRun::Simple::saferunnoerror( IMUNIFY_AGENT, qw{features list} );
        my @features = map {
            my $trim_spaces = $_;
            $trim_spaces =~ s/\s+//g;
            $trim_spaces;
        } grep { m/\S/ } split( "\n", $output );

        foreach my $feature (@features) {

            # If Imunify 360 provides hardened PHP and
            # the ea-cpanel-tools has been updated to the
            # CL version, then we can assume that this system
            # is using CL EA4
            if ( $feature eq 'hardened-php' ) {
                my $version = Cpanel::Pkgr::get_package_version('ea-cpanel-tools');
                return $version =~ m{cloudlinux} ? 1 : 0;
            }
        }
    }

    return 0;
}

sub _get_ea4_profile ($check_mode) {

    my $ea_alias = Elevate::OS::ea_alias();

    $ea_alias = 'CloudLinux_8' if Elevate::EA4::_imunify360_is_installed_and_provides_hardened_php();

    my @cmd = ( '/usr/local/bin/ea_current_to_profile', "--target-os=$ea_alias" );

    my $profile_file;
    if ($check_mode) {

        # use a temporary file in check mode
        $profile_file = Elevate::EA4::tmp_dir() . '/ea_profile.json';
        push @cmd, "--output=$profile_file";
    }

    my $cmd_str = join( ' ', @cmd );

    INFO("Running: $cmd_str");
    my $output = Cpanel::SafeRun::Simple::saferunnoerror(@cmd) // '';
    die qq[Unable to backup EA4 profile. Failure from $cmd_str] if $?;

    if ( !$profile_file ) {

        # parse the output to find the profile file...

        my @lines = split( "\n", $output );

        if ( scalar @lines == 1 ) {
            $profile_file = $lines[0];
        }
        else {
            foreach my $l ( reverse @lines ) {
                next unless $l =~ m{^/.*\.json};
                if ( -f $l ) {
                    $profile_file = $l;
                    last;
                }
            }
        }
    }

    die "Unable to backup EA4 profile running: $cmd_str" unless length $profile_file && -f $profile_file && -s _;
    INFO("Backed up EA4 profile to $profile_file");

    return $profile_file;
}

my $tmp_dir;

sub tmp_dir () {
    return $tmp_dir //= File::Temp->newdir();    # auto cleanup on destroy
}

sub _backup_ea_addons () {

    if ( Cpanel::Pkgr::is_installed('ea-nginx') ) {
        Elevate::StageFile::update_stage_file( { ea4 => { nginx => 1 } } );
    }
    else {
        Elevate::StageFile::update_stage_file( { ea4 => { nginx => 0 } } );
    }

    return;
}

my $php_get_vhost_versions;

sub php_get_vhost_versions () {
    return $php_get_vhost_versions if defined $php_get_vhost_versions && ref $php_get_vhost_versions eq 'HASH';

    my $out    = Cpanel::SafeRun::Simple::saferunnoerror(qw{/usr/local/cpanel/bin/whmapi1 --output=json php_get_vhost_versions});
    my $result = eval { Cpanel::JSON::Load($out); } // {};

    unless ( $result->{metadata}{result} ) {

        WARN( <<~"EOS" );
        The php_get_vhost_versions API call failed. Unable to determine current
        PHP usage by domain.

        EOS

        return;
    }

    my $php_get_vhost_versions = $result->{data}{versions};
    return $php_get_vhost_versions;
}

1;
