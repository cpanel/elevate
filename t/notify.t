#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

package test::cpev::blockers;

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockFile 0.032;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use Test::MockModule qw/strict/;

use Cpanel::JSON;

use cPstrict;

my $notification;
my $mock_notify = Test::MockModule->new('Elevate::Notify');
$mock_notify->redefine(
    send_notification => sub ( $title, $body, %opts ) {
        $notification = {
            title => $title,
            body  => $body,
            opts  => \%opts,
        };
        return;
    }
);

my $cpev = bless {}, 'cpev';

for my $os ( 'cent', 'cloud', 'ubuntu', 'alma' ) {
    set_os_to($os);

    my $stage_file = Test::MockFile->file( Elevate::StageFile::ELEVATE_STAGE_FILE() );

    my $start_os     = Elevate::OS::pretty_name();
    my $expect_os    = Elevate::OS::upgrade_to_pretty_name();
    my $expect_title = "Successfully updated to $expect_os";
    my $expect_body  = "The cPanel & WHM server has completed the elevation process from $start_os to $expect_os.\n";

    $cpev->_notify_success();

    is $notification, {
        title => $expect_title,
        body  => $expect_body,
        opts  => { is_success => 1 },
      },
      " _notify_success"
      or diag explain $notification;

    $notification = {};

    ok Elevate::Notify::add_final_notification("My First Notification"), 'add_final_notification';

    is Elevate::StageFile::read_stage_file(), { final_notifications => ['My First Notification'] }, "stage file - notifications";

    ok !Elevate::Notify::add_final_notification(undef), q[cannot add_final_notification(undef)];
    ok !Elevate::Notify::add_final_notification(''),    q[cannot add_final_notification('')];

    is Elevate::StageFile::read_stage_file(), { final_notifications => ['My First Notification'] }, "stage file - notifications";

    Elevate::Notify::add_final_notification("My Second Notification\nwith two lines.");

    is Elevate::StageFile::read_stage_file(), {
        final_notifications => [
            "My Second Notification\nwith two lines.",
            'My First Notification',
        ]
      },
      "stage file - notifications"
      or diag explain cpev::read_stage_file();

    $cpev->_notify_success();

    is $notification->{title}, "Successfully updated to $expect_os", '_notify_success: title';
    is $notification->{body},  <<EOS,                                '_notify_success: body' or note $notification->{body};
The cPanel & WHM server has completed the elevation process from $start_os to $expect_os.

The update to $expect_os was successful but please note that one ore more notifications require your attention:

* My First Notification

* My Second Notification
with two lines.
EOS
    no_messages_seen();

    $notification = {};
    undef $stage_file;

}

done_testing();
