package Elevate::OS::Ubuntu20;

=encoding utf-8

=head1 NAME

Elevate::OS::Ubuntu20 - Ubuntu20 custom values

=cut

use cPstrict;

use Log::Log4perl qw(:easy);

use parent 'Elevate::OS::Ubuntu';

use constant default_upgrade_to     => 'Ubuntu';
use constant ea_alias               => 'Ubuntu_20.04';
use constant name                   => 'Ubuntu20';
use constant pretty_name            => 'Ubuntu 20.04';
use constant upgrade_to_pretty_name => 'Ubuntu 22.04';

1;
