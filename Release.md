---
title: "cPanel ELevate Release (QA) Preparation"
summary: "Outline of prerequisite criteria for quality assurance testing considerations in preparation to release new versions of cPanel ELevate."
draft: false
date: 2025-04-01T16:20:00Z
---

## cPanel ELevate Release (QA) Preparation

### Automated CI Tests

First and foremost we should have a consistent and passing CI automated test run for supported OSs.

1. Unit/component tests
2. Integration/QA tests

### New Feature & Regression Tests

Changes specific to the new version to be released should pass all pertinent testing.

1. Automated testing is preferred
2. Manual testing where applicable

### Exploratory or Optional Tests

Carefully consider and discuss with your team & peers if any additional testing may be needed and relevant based on the changes committed.

* As an example, if changes primarily affect or target a particular Operating System consider scenarios or use cases that may be most applicable to that OS platform based.
  * CloudLinux OS would be more likely to involve scenarios using a licensed OS-specific feature like MySQL Governor or a plug-in like Imunify360.
  * Other OSs, e.g., AlmaLinux, might be more likely to involve scenarios using free plug-ins like ConfigServer Firewall (CSF) and/or ImunifyAV.
  * Compatibility with various other cPane&WHM plug-ins may also benefit from consideration when evaluating applicable scenarios to test.
    * e.g., Acronis, CCS, InfluxDB, JetBackup, ImunifyAV+, Installatron, KernelCare, LiteSpeed, NixStats, Panopta, R1Soft, Softaculous, WP Toolkit

### Test Failures

If testing fails, results should be carefully evaluated and, as needed, discussed with your team & peers for consensus.  Keep in mind any available data for use cases affected by the issue(s) discovered during testing.

1. The result should not be considered worse than what is already in-use by the public so as to avoid releasing a version with avoidable regressions.
    * e.g., If a new feature is added that is not yet in widespread use, like support for a new Operating System, it may be acceptable provided the changeset is not adversely affecting existing support for other OSs already in widespread use.
2. If the result may be considered worse than what is already public, discuss with your team/peers how to proceed, and consider options to proceed.
    * e.g., Suggest reverting the specific change(s) determined to be the root cause to also allow more time to properly address while not delaying other changes,  the issue(s) and/or suggest holding back the new version until the issue(s) can be adequately addressed.
