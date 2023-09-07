package Elevate::Components::RpmDB;

=encoding utf-8

=head1 NAME

Elevate::Components::RpmDB

Perform some maintenance on the RPM database.

=cut

use cPstrict;

use Elevate::Constants ();

use Cwd           ();
use File::Copy    ();
use Log::Log4perl qw(:easy);

use Cpanel::Pkgr ();

use parent qw{Elevate::Components::Base};

sub pre_leapp ($self) {

    $self->run_once("_cleanup_rpms");

    return;
}

sub _cleanup_rpms ($self) {

    # remove all arch cpanel packages
    # This also potentially removes
    $self->ssystem(q{/usr/bin/rpm -e --justdb --nodeps `/usr/bin/rpm -qa | /usr/bin/egrep '^cpanel-.*\.x86_64'`});

    foreach my $rpm (qw/ yum-plugin-fastestmirror epel-release/) {
        next unless Cpanel::Pkgr::is_installed($rpm);
        $self->ssystem( '/usr/bin/rpm', '-e', '--nodeps', $rpm );
    }

    return;
}

sub post_leapp ($self) {
    return;
}

1;
