#!/usr/local/cpanel/3rdparty/bin/perl

# HARNESS-NO-STREAM

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockModule qw/strict/;

use FindBin;

use Test::MockFile 0.032;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;

$INC{'scripts/ElevateCpanel.pm'} = '__TEST__';

my $mock_elevate = Test::MockModule->new('cpev');
$mock_elevate->redefine(
    ssystem_and_die => sub ( $, @args ) {
        note "run: ", join( ' ', @args );

        return;
    }
);

ok( cpev->_do_leapp_upgrade(), '_do_leapp_upgrade succeeds' );

$mock_elevate->redefine(
    ssystem_and_die => sub {
        die q[Boom!];
    }
);

ok cpev::LEAPP_REPORT_JSON(), 'LEAPP_REPORT_JSON defined';
ok cpev::LEAPP_REPORT_TXT(),  'LEAPP_REPORT_TXT defined';

my $mock_leap_report_json = Test::MockFile->file( cpev::LEAPP_REPORT_JSON() );
my $mock_leap_report_txt  = Test::MockFile->file( cpev::LEAPP_REPORT_TXT() );

like(
    dies { cpev->_do_leapp_upgrade() },
    qr{The 'leapp upgrade' process failed},
    '_do_leapp_upgrade failed'
);

$mock_leap_report_json->contents( <<'EOS' );
{
  "leapp_run_id": "68c0e693-964a-4fac-acfa-9a90d2f86780",
  "entries": [
    {
      "hostname": "leap-upgrade-1.vm.hou-01.cloud.prod.cpanel.net",
      "severity": "high",
      "tags": [
        "repository"
      ],
      "timeStamp": "2021-12-29T23:38:27.002999Z",
      "title": "Packages from unknown repositories may not be installed",
      "detail": {
        "related_resources": [
          {
            "scheme": "package",
            "title": "kernel-uek"
          }
        ],
        "remediations": [
          {
            "type": "hint",
            "context": "Please file a bug in http://bugzilla.redhat.com/ for leapp-repository component of the Red Hat Enterprise Linux product."
          }
        ]
      },
      "actor": "pes_events_scanner",
      "summary": "1 packages may not be installed or upgraded due to repositories unknown to leapp:\n- kernel-uek (repoid: ol8-uek)",
      "audience": "sysadmin",
      "key": "9a2b05abf8f45fd7915e52542887bb334bb218ea",
      "id": "05747351833facc3d8b209f41760eb5372dffc97c91d45d8def52a889b3d3b6e"
    },
    {
      "severity": "high",
      "title": "Missing required answers in the answer file",
      "timeStamp": "2021-12-29T23:39:56.557270Z",
      "hostname": "leap-upgrade-1.vm.hou-01.cloud.prod.cpanel.net",
      "detail": {
        "related_resources": [
          {
            "scheme": "dialog",
            "title": "remove_pam_pkcs11_module_check.confirm"
          }
        ],
        "remediations": [
          {
            "type": "hint",
            "context": "Please register user choices with leapp answer cli command or by manually editing the answerfile."
          },
          {
            "type": "command",
            "context": [
              "leapp",
              "answer",
              "--section",
              "remove_pam_pkcs11_module_check.confirm=True"
            ]
          }
        ]
      },
      "actor": "verify_check_results",
      "summary": "One or more sections in answerfile are missing user choices: remove_pam_pkcs11_module_check.confirm\nFor more information consult https://leapp.readthedocs.io/en/latest/dialogs.html",
      "audience": "sysadmin",
      "flags": [
        "inhibitor"
      ],
      "key": "d35f6c6b1b1fa6924ef442e3670d90fa92f0d54b",
      "id": "c6f620d225195d783a70a87d07403a758ac595ffecf8c7674f55b06e8b9d93ab"
    }
  ]
}
EOS

my $error = dies { cpev->_do_leapp_upgrade() };

note $error;

like(
    $error,
    qr{Please investigate, resolve then re-run the following command},
    '_do_leapp_upgrade failed: Please investigate, resolve then re-run the following command'
);

like(
    $error,
    qr{One or more sections in answerfile are missing user choices},
    '_do_leapp_upgrade failed: One or more sections in answerfile are missing user choices'
);

like(
    $error,
    qr{/usr/bin/leapp answer --section remove_pam_pkcs11_module_check.confirm=True},
    '_do_leapp_upgrade failed: /usr/bin/leapp answer --section remove_pam_pkcs11_module_check.confirm=True'
);

my $report_check = qr{You can read the full leapp report};

unlike(
    $error,
    $report_check,
    'do not advertise leapp report txt'
);

$mock_leap_report_txt->contents('full report');
$error = dies { cpev->_do_leapp_upgrade() };

note $error;

like(
    $error,
    $report_check,
    'advertise leapp report txt'
);

done_testing;
