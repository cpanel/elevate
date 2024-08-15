package Elevate::OS::Ubuntu;

=encoding utf-8

=head1 NAME

Elevate::OS::Ubuntu

ubuntu base class

=cut

use cPstrict;

use Log::Log4perl qw(:easy);

use constant supported_cpanel_mysql_versions => qw{
  8.0
  10.6
  10.11
};

use constant default_upgrade_to              => undef;
use constant ea_alias                        => undef;
use constant is_apt_based                    => 1;
use constant is_supported                    => 1;
use constant lts_supported                   => 118;
use constant name                            => 'Ubuntu';
use constant needs_leapp                     => 0;
use constant pretty_name                     => 'Ubuntu';
use constant provides_mysql_governor         => 0;
use constant should_check_cloudlinux_license => 0;
use constant skip_minor_version_check        => 1;

1;
