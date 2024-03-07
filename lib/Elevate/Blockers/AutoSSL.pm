package Elevate::Blockers::AutoSSL;

=encoding utf-8

=head1 NAME

Elevate::Blockers::AutoSSL

Blocker to check if Sectigo is the AutoSSL provider.

=cut

use cPstrict;

use Cpanel::SSL::Auto ();

use Elevate::Components::AutoSSL ();

use Log::Log4perl qw(:easy);

use parent qw{Elevate::Blockers::Base};

sub check ($self) {

    return $self->_check_autossl_provider();
}

sub _check_autossl_provider ($self) {

    if ( Elevate::Components::AutoSSL::is_using_sectigo() ) {
        WARN( <<~"EOS" );
        Elevating with Sectigo as the provider for AutoSSL is not supported.
        If you proceed with this upgrade, we will switch your system
        to use the Let's Encrypt™ provider.

        EOS
    }

    return 0;
}

1;
