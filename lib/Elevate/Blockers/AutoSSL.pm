package Elevate::Blockers::AutoSSL;

=encoding utf-8

=head1 NAME

Elevate::Blockers::AutoSSL

Blocker to check if Sectigo is the AutoSSL provider.

=cut

use cPstrict;

use Cpanel::SSL::Auto ();

use parent qw{Elevate::Blockers::Base};

sub check ($self) {

    return $self->_check_autossl_provider();
}

sub _check_autossl_provider ($self) {

    my @providers = Cpanel::SSL::Auto::get_all_provider_info();

    foreach my $provider (@providers) {
        next unless ( ref $provider eq 'HASH' && $provider->{enabled} );

        if ( defined $provider->{display_name}
            && $provider->{display_name} =~ /sectigo/i ) {
            return $self->has_blocker( <<~"EOS");
            Elevating with the $provider->{display_name} provider in place is no longer supported.
            To switch to the Let's Encrypt™ provider, review their terms of service here:
            https://letsencrypt.org/documents/LE-SA-v1.3-September-21-2022.pdf
            Then, if you accept, execute this command:

            /usr/local/cpanel/bin/whmapi1 set_autossl_provider provider='LetsEncrypt' x_terms_of_service_accepted=https%3A%2F%2Fletsencrypt.org%2Fdocuments%2FLE-SA-v1.3-September-21-2022.pdf

            EOS
        }
    }

    return 0;
}

1;
