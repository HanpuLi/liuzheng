# Changelog

All notable public changes are recorded here.

## [0.1.1] - 2026-09-19

Installation and contributor UX hardening.

- Add a fail-closed installer that explicitly installs only the four CLI tools, optionally installs the two skills, refuses conflicting destinations before any write, and backs up replaced files/directories when `--force` is explicit.
- Make `webarchive` resolve its sibling `stamp` command so custom installation directories work without a hard-coded `~/bin` dependency.
- Add installer regression tests to CI and release validation.
- Add structured bug/feature issue templates and private security-reporting link.
- Add `CITATION.cff` and enforce VERSION/CITATION consistency in CI and release jobs.

## [0.1.0] - 2026-09-19

Initial public release.

- Two agent skills for institutional correspondence and evidence-preservation discipline.
- `gmail-eml` exports Gmail API raw messages with DKIM/SPF/Received diagnostics and fail-closed path handling.
- `stamp` creates multiple RFC3161/OpenTimestamps anchors and validates timestamp responses before counting a layer.
- `webarchive` hashes, timestamps and appends web evidence to an append-only anchor ledger.
- `ots-upgrade-sweep.sh` upgrades OpenTimestamps receipts and reports receipts that remain unanchored.
- Public CI, gitleaks, CodeQL and branch protection cover the released source tree.
