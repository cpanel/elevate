package Elevate::Blockers::MountPoints;

=encoding utf-8

=head1 NAME

Elevate::Blockers::MountPoints

Blocker to check if '/usr' is a private mount point on a separate partition

=cut

use cPstrict;

use parent qw{Elevate::Blockers::Base};

use constant FINDMNT_BIN => '/usr/bin/findmnt';

use Log::Log4perl qw(:easy);

sub check ($self) {

    my $out = $self->ssystem_capture_output( FINDMNT_BIN, '-no', 'PROPAGATION', '/usr' );

    # This will return 1 if '/usr' is not a separate mount point
    return unless $out->{status} == 0;
    return unless grep { $_ =~ m/private/ } @{ $out->{stdout} };

    return $self->has_blocker( <<~'EOS');
    The current filesystem setup on your server will prevent 'leapp' from being
    able to load these packages which will result in 'leapp' failing which will
    lead to a broken system.  This is being addressed by CloudLinux in
    CLOS-2492.  A potential fix is currently in testing as of May 6th 2024.
    Once the fix is released to the public, this blocker will be removed.

    EOS
}

1;
