# Claude — pre-patch run

This is the output Claude produced in the initial M0 validation pass, **against the original (pre-patch) `dialect.yaml`** — before the 10 convention patches from `planning/convention-validation-report.md` were applied.

Kept for historical reference only. Do NOT compare GPT or Gemini output to this — they run against the patched convention. Compare them to `_validation/runs/claude-post-patch/` instead.

Files here:
- `dialect/source/en.arb` — Claude's expanded source with the 23 extracted keys + 4 seed keys.
- `dialect/translations/*.arb` — Claude's 5-locale translations.
- `dialect/glossary.yaml` — unchanged across patches; included for completeness.

The pre-patch `dialect.yaml` Claude saw is not snapshotted — `git log` on `example/dialect/dialect.yaml` recovers it.
