# Security policy

## Scope

`liuzheng` is evidence-handling tooling. A defect that overwrites evidence, leaks local credentials, records the wrong source, silently reports a failed timestamp as successful, or allows an output path to escape its requested destination should be treated as security-relevant.

The repository intentionally contains **no credentials or case material**. Runtime tools may read operator-owned Gmail OAuth credentials from `~/.gmail-mcp` and may write exported `.eml`, timestamp receipts and archived pages outside this repository.

## Reporting

Use GitHub private vulnerability reporting for security-sensitive findings. Do not attach real email exports, OAuth tokens, case files or other personal evidence to a public issue.

## Local data rules

- Never commit `.eml`, `.tsr`, `.tsq` or `.ots` evidence artifacts.
- Exported email files are created mode `0600` and existing files are not overwritten.
- Web archives use timestamp + content-hash names and refuse collisions rather than replacing an existing archive.
- The tools do not upload case content to this repository.
