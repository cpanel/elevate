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

my $ssystem_cmd;
my $mock_elevate = Test::MockModule->new('cpev');
$mock_elevate->redefine(
    ssystem_and_die => sub ( $, @args ) {
        shift @args;
        $ssystem_cmd = join( ' ', @args );
        note "run: $ssystem_cmd";

        return;
    },
    getopt => sub { return; },
);

my $mock_elevate_leapp = Test::MockModule->new('Elevate::Leapp');
$mock_elevate_leapp->redefine(
    setup_answer_file => sub {    # cannot use Test::MockFile with system touch...
        note "mocked setup_answer_file";
        return;
    },
);

my $mock_elevate_file = Test::MockFile->file('/var/cpanel/elevate');

for my $os ( 'cent', 'cloud' ) {
    set_os_to($os);

    my $expect_cmd = '/usr/bin/leapp upgrade';
    $expect_cmd .= ' --nowarn' if $os eq 'cloud';
    ok( cpev->leapp->upgrade(), 'leapp upgrade succeeds' );
    is( $ssystem_cmd, $expect_cmd );
}

$mock_elevate->redefine(
    ssystem_and_die => sub {
        die q[Boom!];
    }
);

ok Elevate::Leapp::LEAPP_REPORT_JSON(), 'LEAPP_REPORT_JSON defined';
ok Elevate::Leapp::LEAPP_REPORT_TXT(),  'LEAPP_REPORT_TXT defined';

my $mock_leap_report_json  = Test::MockFile->file( Elevate::Leapp::LEAPP_REPORT_JSON() );
my $mock_leap_report_txt   = Test::MockFile->file( Elevate::Leapp::LEAPP_REPORT_TXT() );
my $mock_leapp_upgrade_log = Test::MockFile->file( Elevate::Leapp::LEAPP_UPGRADE_LOG() );
my $mock_leapp_cont_file   = Test::MockFile->file( Elevate::Leapp::LEAPP_FAIL_CONT_FILE() );

like(
    dies { cpev->leapp->upgrade() },
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
    },
    {
      "actor": "special_test_blocker",
      "title": "Test Blocker",
      "summary": "This should be picked up by the unit test",
      "flags": [
        "inhibitor"
      ],
      "detail": {
        "remediations": [
          {
            "type": "hint",
            "context": "This is the test blocker hint"
          },
          {
            "type": "command",
            "context": [
              "unblock",
              "me",
              "right",
              "now"
            ]
          }
        ]
      }
    }
  ]
}
EOS

my $error = dies { cpev->leapp->upgrade() };

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
$error = dies { cpev->leapp->upgrade() };

note $error;

like(
    $error,
    $report_check,
    'advertise leapp report txt'
);

my $expected_blockers = [
    {
        title   => "Test Blocker",
        summary => "This should be picked up by the unit test",
        hint    => "This is the test blocker hint",
        command => "unblock me right now",
    }
];

my $found_blockers = cpev->leapp->search_report_file_for_blockers(
    qw(
      check_installed_devel_kernels
      verify_check_results
    )
);

is $found_blockers, $expected_blockers, 'Properly parsed output JSON file for blockers';

$mock_leap_report_json->contents('bad json content');

$expected_blockers = [
    {
        title   => "Unable to parse leapp report file " . Elevate::Leapp::LEAPP_REPORT_JSON(),
        summary => "The JSON report file generated by LEAPP is unreadable or corrupt",
    }
];

# This keeps Cpanel::Exception from throwing errors by accessing ummocked locale files
local $Cpanel::Exception::LOCALIZE_STRINGS = 0;

$found_blockers = cpev->leapp->search_report_file_for_blockers();

is $found_blockers, $expected_blockers, 'Returned blocker for invalid JSON in report file';

{
    my $label = 'LEAPP upgrade log failure checks';

    $mock_elevate->redefine(
        ssystem_capture_output => sub ( $, @args ) {
            $ssystem_cmd = join( ' ', @args );
            note "run: $ssystem_cmd";

            my @out;
            if ( $ssystem_cmd =~ /ERROR/ ) {
                my @lines = split( '\n', $mock_leapp_upgrade_log->contents() );
                foreach my $line (@lines) {
                    if ( $line =~ /ERROR/ ) {
                        push @out, $line;
                    }
                }
                return { stdout => [@out], stderr => [] };
            }
            else {
                my @lines = split( '\n', $mock_leapp_upgrade_log->contents() );
                foreach my $line (@lines) {
                    if ( $line =~ /Starting stage After/ ) {
                        push @out, $line;
                    }
                }
                return { stdout => [@out], stderr => [] };
            }
        }
    );

    # Upgrade log file contents with no errors
    $mock_leapp_upgrade_log->contents(
        "2024-03-18 16:45:18.386 INFO     PID: 1258 leapp.workflow.FirstBoot: Starting stage After of phase FirstBoot\n2024-03-18 16:45:18.362 DEBUG    PID: 2150 leapp.workflow.FirstBoot.enable_rhsm_target_repos: Skipping setting the RHSM release due to --no-rhsm or environment variables.\n2024-03-18 16:45:18.368 DEBUG    PID: 2150 leapp.workflow.FirstBoot.enable_rhsm_target_repos: Skipping enabling repositories through subscription-manager due to --no-rhsm or environment variables."
    );
    my $out = cpev->leapp->check_upgrade_log_for_failures();
    is( $out, 0, "$label: check_upgrade_log_for_failures returns the proper value when no errors are found." );
}

{
    my $label = 'LEAPP upgrade log failure checks';

    $mock_elevate->redefine(
        ssystem_capture_output => sub ( $, @args ) {
            $ssystem_cmd = join( ' ', @args );
            note "run: $ssystem_cmd";

            my @out;
            if ( $ssystem_cmd =~ /ERROR/ ) {
                my @lines = split( '\n', $mock_leapp_upgrade_log->contents() );
                foreach my $line (@lines) {
                    if ( $line =~ /ERROR/ ) {
                        push @out, $line;
                    }
                }
                return { stdout => [@out], stderr => [] };
            }
            else {
                my @lines = split( '\n', $mock_leapp_upgrade_log->contents() );
                foreach my $line (@lines) {
                    if ( $line =~ /Starting stage After/ ) {
                        push @out, $line;
                    }
                }
                return { stdout => [@out], stderr => [] };
            }
        }
    );

    # Upgrade log file contents with errors
    $mock_leapp_upgrade_log->contents(
        "2024-03-18 16:45:18.386 INFO     PID: 1258 leapp.workflow.FirstBoot: Starting stage After of phase FirstBoot\n2024-03-18 16:45:18.362 DEBUG    PID: 2150 leapp.workflow.FirstBoot.enable_rhsm_target_repos: Skipping setting the RHSM release due to --no-rhsm or environment variables.\n2024-03-18 16:45:18.368 DEBUG    PID: 2150 leapp.workflow.FirstBoot.enable_rhsm_target_repos: Skipping enabling repositories through subscription-manager due to --no-rhsm or environment variables.\n2024-03-18 16:45:18.368 ERROR    PID: 2150 leapp.workflow.FirstBoot.enable_rhsm_target_repos: Skipping enabling repositories through subscription-manager due to --no-rhsm or environment variables."
    );
    my $out = cpev->leapp->check_upgrade_log_for_failures();
    is( $out, 1, "$label: check_upgrade_log_for_failures returns the proper value when errors are found." );
    undef $out;

    $mock_leapp_upgrade_log->contents(
        "2024-03-18 16:45:18.362 DEBUG    PID: 2150 leapp.workflow.FirstBoot.enable_rhsm_target_repos: Skipping setting the RHSM release due to --no-rhsm or environment variables.\n2024-03-18 16:45:18.368 DEBUG    PID: 2150 leapp.workflow.FirstBoot.enable_rhsm_target_repos: Skipping enabling repositories through subscription-manager due to --no-rhsm or environment variables.\n");
    $out = cpev->leapp->check_upgrade_log_for_failures();
    is( $out, 1, "$label: check_upgrade_log_for_failures returns the proper value when the upgrade log shows the LEAPP process may not have finished." );
}

{
    my $label = 'LEAPP upgrade log failure checks';

    my $out = cpev->leapp->check_upgrade_log_for_failures();
    is( $out, 1, "$label: check_upgrade_log_for_failures returns the proper value when the upgrade log does not exist." );
    undef $out;

    $mock_leapp_cont_file->contents("1");
    $mock_leapp_upgrade_log->contents(
        "2024-03-18 16:45:18.386 INFO     PID: 1258 leapp.workflow.FirstBoot: Starting stage After of phase FirstBoot\n2024-03-18 16:45:18.362 DEBUG    PID: 2150 leapp.workflow.FirstBoot.enable_rhsm_target_repos: Skipping setting the RHSM release due to --no-rhsm or environment variables.\n2024-03-18 16:45:18.368 DEBUG    PID: 2150 leapp.workflow.FirstBoot.enable_rhsm_target_repos: Skipping enabling repositories through subscription-manager due to --no-rhsm or environment variables.\n2024-03-18 16:45:18.368 ERROR    PID: 2150 leapp.workflow.FirstBoot.enable_rhsm_target_repos: Skipping enabling repositories through subscription-manager due to --no-rhsm or environment variables."
    );
    $out = cpev->leapp->check_upgrade_log_for_failures();
    is( $out, 0, "$label: check_upgrade_log_for_failures returns the proper value when the upgrade log has errors but the touch file exists." );
    undef $out;

    $mock_leapp_upgrade_log->contents(
        "2024-03-18 16:45:18.362 DEBUG    PID: 2150 leapp.workflow.FirstBoot.enable_rhsm_target_repos: Skipping setting the RHSM release due to --no-rhsm or environment variables.\n2024-03-18 16:45:18.368 DEBUG    PID: 2150 leapp.workflow.FirstBoot.enable_rhsm_target_repos: Skipping enabling repositories through subscription-manager due to --no-rhsm or environment variables.");
    $out = cpev->leapp->check_upgrade_log_for_failures();
    is( $out, 0, "$label: check_upgrade_log_for_failures returns the proper value when the LEAPP process may not have finished, but the touch file exists." );
}

done_testing;
