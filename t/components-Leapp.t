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
                num_blockers_found => sub { "do not call\n"; },
            );

            $mock_comp->redefine(
                is_check_mode => 1,
            );

            is( $comp->check(), undef, 'Returns early if in check mode' );

            $mock_comp->redefine(
                is_check_mode => 0,
            );
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
        }
    }

    $mock_comp->unmock('_remove_excludes');
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
