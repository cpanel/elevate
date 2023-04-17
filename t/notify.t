#!/usr/local/cpanel/3rdparty/bin/perl

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
my $mock_cpev = Test::MockModule->new('cpev');
$mock_cpev->redefine(
    send_notification => sub ( $title, $body, %opts ) {
        $notification = {
            title => $title,
            body  => $body,
            opts  => \%opts,
        };
        return;
    }
);

my $stage_file = Test::MockFile->file( cpev::ELEVATE_STAGE_FILE() );

my $cpev = bless {}, 'cpev';

$cpev->_notify_success();

is $notification, {
    title => 'Successfully updated to AlmaLinux 8',
    body  => qq[The cPanel & WHM server has completed the elevation process from CentOS 7 to AlmaLinux 8.\n],
    opts  => { is_success => 1 },
  },
  " _notify_success"
  or diag explain $notification;

$notification = {};

ok Elevate::Notify::add_final_notification("My First Notification"), 'add_final_notification';

is cpev::read_stage_file(), { final_notifications => ['My First Notification'] }, "stage file - notifications";

ok !Elevate::Notify::add_final_notification(undef), q[cannot add_final_notification(undef)];
ok !Elevate::Notify::add_final_notification(''),    q[cannot add_final_notification('')];

is cpev::read_stage_file(), { final_notifications => ['My First Notification'] }, "stage file - notifications";

Elevate::Notify::add_final_notification("My Second Notification\nwith two lines.");

is cpev::read_stage_file(), {
    final_notifications => [
        "My Second Notification\nwith two lines.",
        'My First Notification',
    ]
  },
  "stage file - notifications"
  or diag explain cpev::read_stage_file();

$cpev->_notify_success();

is $notification->{title}, 'Successfully updated to AlmaLinux 8', '_notify_success: title';
is $notification->{body},  <<EOS,                                 '_notify_success: body' or note $notification->{body};
The cPanel & WHM server has completed the elevation process from CentOS 7 to AlmaLinux 8.

The update to AlmaLinux 8 was successful but please note that one ore more notifications require your attention:

* My First Notification

* My Second Notification
with two lines.
EOS
no_messages_seen();

done_testing();
