package Elevate::Components::AutoSSL;

=encoding utf-8

=head1 NAME

Elevate::Components::AutoSSL

Change AutoSSL provider from Sectigo to Lets Encrypt

=cut

use cPstrict;

use Cpanel::SSL::Auto ();

use parent qw{Elevate::Components::Base};

sub pre_distro_upgrade ($self) {

    if ( is_using_sectigo() ) {
        $self->ssystem_and_die(qw{/usr/local/cpanel/scripts/autorepair set_autossl_to_lets_encrypt});
    }

    return;
}

sub post_distro_upgrade ($self) {

    # Nothing to do
    return;
}

=head2 is_using_sectigo()

Determines whether AutoSSL is using Sectigo as a provider

=head3 ARGUMENTS

None

=head3 RETURNS

true/false if AutoSSL is/isn't using Sectigo

=cut

sub is_using_sectigo {

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
