package Elevate::Components::AutoSSL;

=encoding utf-8

=head1 NAME

Elevate::Components::AutoSSL

=head2 check

Warn if Sectigo is the provider for AutoSSL

=head2 pre_distro_upgrade

Update the AutoSSL provider to LE

=head2 post_distro_upgrade

noop

=cut

use cPstrict;

use Cpanel::SSL::Auto ();

use parent qw{Elevate::Components::Base};

use Log::Log4perl qw(:easy);

sub check ($self) {

    return $self->_check_autossl_provider();
}

sub _check_autossl_provider ($self) {

    if ( $self->is_using_sectigo() ) {
        WARN( <<~"EOS" );
        Elevating with Sectigo as the provider for AutoSSL is not supported.
        If you proceed with this upgrade, we will switch your system
        to use the Let's Encrypt™ provider.

        EOS
    }

    return 0;
}

sub pre_distro_upgrade ($self) {

    if ( $self->is_using_sectigo() ) {
        $self->ssystem_and_die(qw{/usr/local/cpanel/scripts/autorepair set_autossl_to_lets_encrypt});
    }

    return;
}

=head2 is_using_sectigo()

Determines whether AutoSSL is using Sectigo as a provider

=head3 ARGUMENTS

None

=head3 RETURNS

true/false if AutoSSL is/isn't using Sectigo

=cut

sub is_using_sectigo ($self) {

    my @providers = Cpanel::SSL::Auto::get_all_provider_info();

    foreach my $provider (@providers) {
        next unless ( ref $provider eq 'HASH' && $provider->{enabled} );

        if ( defined $provider->{display_name}
            && $provider->{display_name} =~ /sectigo/i ) {
            return 1;
        }
    }

    return 0;
}

1;
