package Elevate::Components::CryptoPolicies;

=encoding utf-8

=head1 NAME

Elevate::Components::CryptoPolicies

=head2 check

Ensure that a compatible policy is set. If not, let the user know that they
need to use the default policy.

=head2 pre_distro_upgrade

On appropriate systems, ensure that the needed SHA1 policy is set

=head2 post_distro_upgrade

On appropriate systems, remove the C<SHA1.pmod> file we created, so that
the upgraded system uses the one provided by the system.

=cut

use cPstrict;

use Elevate::OS             ();
use Cpanel::SafeRun::Simple ();
use File::Path              ();
use Log::Log4perl           qw(:easy);

use parent qw{Elevate::Components::Base};

use constant CUSTOM_MODULE_TEXT => <<EOF;
# ELevate's temporary module definition for SHA-1 support
hash = SHA1+
sign = ECDSA-SHA1+ RSA-PSS-SHA1+ RSA-SHA1+
sha1_in_certs = 1
EOF

# allow tests to override this
sub UPDATE_CRYPTO_POLICIES_PATH { return "/usr/bin/update-crypto-policies"; }
sub CRYPTO_POLICIES_MODULE_PATH { return "/etc/crypto-policies/policies/modules"; }
sub CPANEL_MODULE_FILE          { return "/usr/local/cpanel/etc/crypto-policies/CPANEL-SHA1.pmod"; }

sub check ($self) {

    return unless Elevate::OS::has_crypto_policies() && Elevate::OS::needs_sha1_enabled();

    return $self->has_blocker(<<~"EOS") unless Cpanel::Pkgr::is_installed('crypto-policies') && Cpanel::Pkgr::is_installed('crypto-policies-scripts');
    ELevate expects to see the crypto-policies and crypto-policies-scripts packages
    installed, but one or both are missing. This should not be possible, so this
    suggests a severely broken system, but you can try installing these packages
    anyway:

    dnf -y install crypto-policies crypto-policies-scripts

    EOS

    return $self->has_blocker(<<~"EOS") unless -x UPDATE_CRYPTO_POLICIES_PATH();
    There appear to be some file permission issues with the system's
    cryptographic policies framework. You can try re-installing the packages to see
    if this fixes the issue:

    dnf -y reinstall crypto-policies crypto-policies-scripts

    EOS

    my $current_policy = $self->current_policy();

    # Leapp currently demands that the policy be exactly DEFAULT:SHA1 or
    # LEGACY. For the purposes of this check, DEFAULT is also accepted, because
    # we will convert it to DEFAULT:SHA1 before upgrade.

    return if $current_policy =~ m/^(?:(?:DEFAULT(:SHA1)?)|LEGACY)$/;

    return $self->has_blocker(<<~"EOS");
    The system's cryptographic policy is set to a value ($current_policy)
    which is not compatible with ELevate. We recommend that you set the
    cryptographic policy to the default for your distribution:

    /usr/bin/update-crypto-policies --set DEFAULT

    EOS
}

sub pre_distro_upgrade ($self) {

    return unless Elevate::OS::has_crypto_policies() && Elevate::OS::needs_sha1_enabled();

    $self->prepare_system_for_sha1_policy_changes();
    $self->set_custom_crypto_policy();

    return;
}

sub set_custom_crypto_policy ($self) {
    return if Elevate::OS::os_provides_sha1_module();

    my $custom_crypto_policies_file = CRYPTO_POLICIES_MODULE_PATH() . '/CPANEL-SHA1.pmod';
    File::Copy::cp( CPANEL_MODULE_FILE(), $custom_crypto_policies_file );
    $self->set_policy('DEFAULT:CPANEL-SHA1');

    return;
}

sub prepare_system_for_sha1_policy_changes ($self) {
    return unless Elevate::OS::os_provides_sha1_module();

    my $current_policy = $self->current_policy();

    # Leapp currently demands that the policy be exactly DEFAULT:SHA1 or
    # LEGACY. Sorry, FUTURE and FIPS users...
    return if $current_policy eq 'DEFAULT:SHA1' || $current_policy eq 'LEGACY';

    LOGDIE("Unexpected crypto policy \"$current_policy\"; this should have been caught during checks!") unless $current_policy eq 'DEFAULT';

    my $filename = CRYPTO_POLICIES_MODULE_PATH . "/SHA1.pmod";

    # It is unlikely but possible that the user provided a custom SHA1.pmod. If
    # they did this, move it out of the way.
    #
    # If the file exists but hasn't been backed up, we can assume the file
    # isn't ours and back it up. If it exists and has a backup, we can assume
    # that the file is ours from a previous run.
    if ( -e $filename && !-e "$filename.elevate.bak" ) {
        WARN("Custom $filename detected; renaming existing file to $filename.elevate.bak.");
        rename( $filename, "$filename.elevate.bak" ) or LOGDIE("Could not rename $filename to $filename.elevate.bak: $!");
    }

    # If it doesn't exist, or if it is empty, we can safely assume that we can try to write it out.
    if ( !-e $filename || -z _ ) {
        open( my $fd, '>', $filename ) or LOGDIE("Could not open $filename for write: $!");
        print {$fd} CUSTOM_MODULE_TEXT;
        close $fd or do {
            unlink $filename;
            LOGDIE("Could not write/close $filename: $!");
        };
    }

    INFO("Applying new cryptographic policy:");
    $self->set_policy('DEFAULT:SHA1');

    return;
}

sub post_distro_upgrade ($self) {

    return unless Elevate::OS::has_crypto_policies() && Elevate::OS::needs_sha1_enabled();

    $self->set_to_os_provided_sha1_policy();

    return;
}

sub set_to_os_provided_sha1_policy ($self) {
    return unless Elevate::OS::os_provides_sha1_module();

    my $current_policy = $self->current_policy();

    # If the user needs overly-relaxed security, don't accidentally fix it for them.
    return if $current_policy eq 'LEGACY';

    # Remove the temporary module definition.
    my $filename = CRYPTO_POLICIES_MODULE_PATH() . "/SHA1.pmod";
    unlink $filename if -e $filename;

    # Re-apply the modified default policy using the system-provided module.
    INFO("Re-applying new cryptographic policy using system definitions:");
    $self->set_policy('DEFAULT:SHA1');

    return;
}

sub current_policy ($self) {
    my $current_policy = uc Cpanel::SafeRun::Simple::saferunnoerror( UPDATE_CRYPTO_POLICIES_PATH(), '--show' );
    chomp $current_policy;
    return $current_policy;
}

sub set_policy ( $self, $policy ) {
    return $self->ssystem_and_die( UPDATE_CRYPTO_POLICIES_PATH(), '--set', uc $policy );
}

1;
