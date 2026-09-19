# Changelog

All notable public changes are recorded here.

## [0.1.0] - 2026-09-19

Initial public release.

- Two agent skills for institutional correspondence and evidence-preservation discipline.
- `gmail-eml` exports Gmail API raw messages with DKIM/SPF/Received diagnostics and fail-closed path handling.
- `stamp` creates multiple RFC3161/OpenTimestamps anchors and validates timestamp responses before counting a layer.
- `webarchive` hashes, timestamps and appends web evidence to an append-only anchor ledger.
- `ots-upgrade-sweep.sh` upgrades OpenTimestamps receipts and reports receipts that remain unanchored.
- Public CI, gitleaks, CodeQL and branch protection cover the released source tree.
