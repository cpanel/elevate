package Elevate::Components::Repositories;

=encoding utf-8

=head1 NAME

Elevate::Components::Repositories

Disable some repostiories.

=cut

use cPstrict;

use Elevate::Constants              ();
use Elevate::Blockers::Repositories ();

use Cpanel::SafeRun::Simple ();
use Cwd                     ();
use File::Copy              ();
use Log::Log4perl           qw(:easy);

use parent qw{Elevate::Components::Base};

sub pre_leapp ($self) {

    $self->run_once("_disable_known_yum_repositories");

    return;
}

sub _disable_known_yum_repositories {

    # remove all MySQL repos
    my @repo_files = map { Elevate::Constants::YUM_REPOS_D . '/' . $_ }    #
      Elevate::Blockers::Repositories::DISABLE_MYSQL_YUM_REPOS;

    foreach my $f (@repo_files) {
        next unless -e $f;
        if ( -l $f ) {
            unlink $f;
            next;
        }

        File::Copy::move( $f, "$f.off" ) or die qq[Failed to disable repo $f];
    }

    Cpanel::SafeRun::Simple::saferunnoerror(qw{/usr/bin/yum clean all});

    return;
}

1;
