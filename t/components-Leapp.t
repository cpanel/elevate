#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

package test::cpev::components;

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;
use Test2::Tools::Mock;

use Test::MockModule qw/strict/;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;

my $mock_comp         = Test::MockModule->new('Elevate::Components::Leapp');
my $mock_elevate_comp = Test::MockModule->new('Elevate::Components');
my $mock_leapp        = Test::MockModule->new('Elevate::Leapp');

my $comp = cpev->new->get_component('Leapp');

{
    note 'Test blocker when --upgrade-distro-manually is passed';

    my %os_hash = (
        alma => [8],
        cent => [7],
    );
    foreach my $distro ( keys %os_hash ) {
        next if $distro ne 'cent' && $distro ne 'alma';
        foreach my $version ( @{ $os_hash{$distro} } ) {
            set_os_to( $distro, $version );

            $mock_elevate_comp->redefine(
                num_blockers_found => sub { die "Do not call\n"; },
            );

            $mock_leapp->redefine(
                install                  => sub { die "Do not call\n"; },
                remove_leftover_kmod_lve => sub { die "Do not call\n"; },
                preupgrade               => sub { die "Do not call\n"; },
            );

            $mock_comp->redefine(
                is_check_mode => 1,
            );

            is( $comp->check(), undef, 'Returns early if in check mode without installing leapp or removing packages' );

            $mock_comp->redefine(
                is_check_mode => 0,
            );

            $mock_leapp->unmock(qw{ install remove_leftover_kmod_lve preupgrade });
        }
    }

    set_os_to( 'ubuntu', 20 );
    is( $comp->check(), undef, 'Returns early if the OS does not rely on leapp to upgrade' );

    foreach my $distro ( keys %os_hash ) {
        next if $distro ne 'cent' && $distro ne 'alma';
        foreach my $version ( @{ $os_hash{$distro} } ) {
            set_os_to( $distro, $version );

            $mock_leapp->redefine(
                install => sub { die "Do not call\n"; },
            );

            $mock_elevate_comp->redefine(
                num_blockers_found => 1,
            );

            is( $comp->check(), undef, 'Returns early if there are existing blockers found' );

            my $num_blockers_found = 0;
            $mock_elevate_comp->redefine(
                num_blockers_found => sub { return $num_blockers_found; },
            );

            $mock_comp->redefine(
                _check_for_inhibitors   => sub { $num_blockers_found++; return; },
                _check_for_fatal_errors => 0,
                _remove_excludes        => 0,
            );

            my $preupgrade_out;
            $mock_leapp->redefine(
                install    => 1,
                preupgrade => sub { return $preupgrade_out; },
            );

            $preupgrade_out = {
                status => 0,
            };

            my $mock_file_copy = Test::MockModule->new('File::Copy');
            $mock_file_copy->redefine(
                cp => 0,
            );

            is( $comp->check(), undef, 'No blockers returns if leapp preupgrade returns clean' );
            no_messages_seen();

            $preupgrade_out = {
                status => 42,
            };

            is( $comp->check(), undef, 'Returns undef' );
            message_seen( INFO => qr/Leapp found issues which would prevent the upgrade/ );
            no_messages_seen();

            # The inhibitor check above counted a blocker
            $num_blockers_found = 0;

            my @calls;
            $mock_leapp->redefine(
                remove_leftover_kmod_lve => sub { push @calls, 'remove_leftover_kmod_lve'; return; },
                preupgrade               => sub { push @calls, 'preupgrade';               return { status => 0 }; },
            );

            is( $comp->check(), undef,                                       'Returns undef' );
            is( \@calls,        [qw{ remove_leftover_kmod_lve preupgrade }], 'Leftover kmod-lve packages are removed before leapp preupgrade' );

            @calls = ();
            $mock_leapp->redefine(
                remove_leftover_kmod_lve => sub { push @calls, 'remove_leftover_kmod_lve'; die "rpm exploded\n"; },
            );

            my @blockers;
            $mock_comp->redefine(
                has_blocker => sub ( $, $msg, %others ) { push @blockers, $msg; is( $others{info}, { name => 'kmod-lve' }, 'The blocker includes analytics info' ); return; },
            );

            is( $comp->check(),   undef,                        'Returns undef when leftover kmod-lve packages cannot be removed' );
            is( \@calls,          ['remove_leftover_kmod_lve'], 'leapp preupgrade is not run when leftover kmod-lve packages cannot be removed' );
            is( scalar @blockers, 1,                            'A blocker is raised' );
            like( $blockers[0], qr/unable to remove the superseded kmod-lve packages.*\n\nrpm exploded\n/s, 'The blocker includes the error' );
            no_messages_seen();

            like( $blockers[0], qr{-printf '%p -> %l\\n'}, 'The blocker shows the weak-updates command verbatim' );

            $mock_comp->unmock('has_blocker');
            $mock_leapp->unmock('remove_leftover_kmod_lve');
            $mock_leapp->redefine( preupgrade => sub { return $preupgrade_out; } );
        }
    }

    $mock_comp->unmock('_remove_excludes');
}

{
    note 'Testing pre_distro_upgrade';

    my @calls;
    $mock_comp->redefine(
        run_once => sub ( $, $sub ) { push @calls, $sub; return; },
    );
    $mock_leapp->redefine(
        remove_leftover_kmod_lve => sub { push @calls, 'remove_leftover_kmod_lve'; return; },
    );

    is( $comp->pre_distro_upgrade(), undef,                                             'Returns undef' );
    is( \@calls,                     [qw{ _remove_excludes remove_leftover_kmod_lve }], 'Removes the excludes and leftover kmod-lve packages' );

    @calls = ();
    my $mock_cpev = Test::MockModule->new('cpev');
    $mock_cpev->redefine( upgrade_distro_manually => 1 );
    $mock_leapp->redefine( warn_leftover_kmod_lve => sub { push @calls, 'warn_leftover_kmod_lve'; return; } );
    is( $comp->pre_distro_upgrade(), undef,                                           'Returns undef when the distro is upgraded manually' );
    is( \@calls,                     [qw{ _remove_excludes warn_leftover_kmod_lve }], 'Leftover kmod-lve packages are only warned about when the distro is upgraded manually' );
    $mock_cpev->unmock('upgrade_distro_manually');
    $mock_leapp->unmock('warn_leftover_kmod_lve');

    $mock_leapp->redefine(
        remove_leftover_kmod_lve => sub { die "rpm exploded\n"; },
    );

    like(
        dies { $comp->pre_distro_upgrade() },
        qr/unable to remove the superseded kmod-lve packages.*\n\nrpm exploded\n.*-printf '%p -> %l\\n'/s,
        'Dies with the error and the remediation steps when leftover kmod-lve packages cannot be removed',
    );

    $mock_comp->unmock('run_once');
    $mock_leapp->unmock('remove_leftover_kmod_lve');
}

{
    note 'Testing _remove_excludes';

    my %os_hash = (
        alma   => [ 8, 9 ],
        cent   => [7],
        cloud  => [ 7,  8 ],
        ubuntu => [ 20, 22 ],
    );

    foreach my $distro ( sort keys %os_hash ) {
        next if $distro eq 'ubuntu';
        foreach my $version ( @{ $os_hash{$distro} } ) {
            set_os_to( $distro, $version );

            my $content;
            my $actual_content;
            my $mock_file_slurper = Test::MockModule->new('File::Slurper');
            $mock_file_slurper->redefine(
                read_text  => sub { return $content; },
                write_text => sub { $actual_content = $_[1]; },
            );

            $content = <<'EOS';
[main]
exclude=bind-chroot dovecot* exim* filesystem nsd* p0f php* proftpd* pure-ftpd*
tolerant=1
plugins=1
gpgcheck=1
installonly_limit=3
clean_requirements_on_remove=True
best=True
skip_if_unavailable=False
minrate=50k
ip_resolve=4
EOS

            my $expected_content = <<'EOS';
[main]

tolerant=1
plugins=1
gpgcheck=1
installonly_limit=3
clean_requirements_on_remove=True
best=True
skip_if_unavailable=False
minrate=50k
ip_resolve=4
EOS

            is( $comp->_remove_excludes(), undef,             'Returns undef' );
            is( $actual_content,           $expected_content, 'Successfully removes the excludes line from yum.conf' );

            message_seen( INFO => 'Removing excludes from /etc/yum.conf' );
            no_messages_seen();
        }
    }
}

done_testing();
