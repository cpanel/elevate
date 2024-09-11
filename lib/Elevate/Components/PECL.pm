package Elevate::Components::PECL;

=encoding utf-8

=head1 NAME

Elevate::Components::PECL

Capture and reinstall PECL packages.

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::StageFile ();

use Cpanel::JSON            ();
use Cpanel::SafeRun::Simple ();

use Cwd           ();
use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

sub pre_distro_upgrade ($self) {

    $self->run_once("_backup_pecl_packages");

    return;
}

sub post_distro_upgrade ($self) {

    $self->run_once('_check_pecl_packages');

    return;
}

sub _backup_pecl_packages ($self) {
    my $out    = Cpanel::SafeRun::Simple::saferunnoerror(qw{/usr/local/cpanel/bin/whmapi1 --output=json php_get_installed_versions});
    my $result = eval { Cpanel::JSON::Load($out); } // {};

    unless ( $result->{metadata}{result} ) {
        WARN( <<~"EOS" );
        Unable to determine the installed PHP versions.
        Assuming that backing up PECL packages is not relevant as such.

        EOS
        return;
    }

    foreach my $v ( @{ $result->{'data'}{'versions'} } ) {
        _store_pecl_for( qq[/opt/cpanel/$v/root/usr/bin/pecl], $v );
    }

    _store_pecl_for( q[/usr/local/cpanel/3rdparty/bin/pecl], 'cpanel' );

    return;
}

sub _check_pecl_packages ($self) {

    my $pecl = Elevate::StageFile::read_stage_file('pecl');

    return unless ref $pecl && scalar keys $pecl->%*;

    foreach my $v ( sort keys $pecl->%* ) {
        my $previously_installed = $pecl->{$v};

        return unless ref $previously_installed && scalar keys $previously_installed->%*;

        my $bin;
        if ( $v eq 'cpanel' ) {
            $bin = q[/usr/local/cpanel/3rdparty/bin/pecl];
        }
        else {
            $bin = qq[/opt/cpanel/$v/root/usr/bin/pecl];
        }

        my $currently_installed = _get_pecl_installed_for($bin) // {};

        my $final_notification;

        my $displayed_header = 0;
        foreach my $pkg ( sort keys $previously_installed->%* ) {
            next if $currently_installed->{$pkg};

            # for now do not check the version

            if ( !$displayed_header ) {
                $displayed_header = 1;
                WARN( q[*] x 20 );

                $final_notification = <<~"EOS";
                WARNING: Missing pecl package(s) for $bin
                Please reinstall these packages:
                EOS

                foreach my $l ( split( "\n", $final_notification ) ) {
                    next unless length $l;
                    WARN($l);
                }

                WARN( q[*] x 20 );
            }

            WARN("- $pkg");
            $final_notification .= qq[- $pkg\n];
        }

        Elevate::Notify::add_final_notification($final_notification);

        WARN('#') if $displayed_header;
    }

    return;
}

sub _store_pecl_for ( $bin, $name ) {
    my $list = _get_pecl_installed_for($bin);

    Elevate::StageFile::remove_from_stage_file("pecl.$name");

    return unless ref $list && scalar keys $list->%*;

    Elevate::StageFile::update_stage_file( { pecl => { $name => $list } } );

    return;
}

sub _get_pecl_installed_for ($bin) {

    return unless -x $bin;

    my $out = Cpanel::SafeRun::Simple::saferunnoerror( $bin, 'list' ) // '';
    return if $?;

    my @lines = split( /\n/, $out );
    return unless scalar @lines >= 4;

    shift @lines for 1 .. 3;    # remove the header

    my $installed;

    foreach my $l (@lines) {
        my ( $package, $v, $state ) = split( /\s+/, $l, 3 );
        $installed->{$package} = $v;
    }

    return $installed;
}

1;
