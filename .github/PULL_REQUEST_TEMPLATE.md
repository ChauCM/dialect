<!-- Thanks for contributing to Dialect. -->

## Summary

<!-- One or two sentences on what this PR changes and why. -->

## Test plan

<!-- A checklist of what you ran locally. Include `dart test`, `dart analyze`,
     and any manual invocations of `dart run bin/dialect.dart <command>`. -->

- [ ] `dart analyze` — clean
- [ ] `dart test` — green
- [ ]

## Anti-goal checklist

Every feature PR must answer **no** to each of these before merge. If your
PR answers **yes** to any of them, expect to be asked to scope it down or
move it out of v1. Background in [CLAUDE.md §6](../CLAUDE.md#6-anti-goals-dont-do-these)
and [planning/competitive-strategy.md](../planning/competitive-strategy.md).

- [ ] **No** — does this make Dialect parse source code (`.dart` / `.kt` / `.swift` / `.cs`)? *AI-pointer flow only — Dialect writes plan files, the user's AI executes them.*
- [ ] **No** — does this ship a `.resx` or `.po` adapter? *Backend Humility — lossless `icu-json` + a localizer library per stack.*
- [ ] **No** — does this add telemetry, version-check pings, or any phone-home? *v1.0 anti-goal; the CLI must run fully offline (except `dialect translate --auto`, which is v1.2).*
- [ ] **No** — does this make `dialect translate --auto` the default behavior of `dialect translate`? *AI-pointer is primary; `--auto` is a CI convenience.*
- [ ] **No** — does this target React-web-only, regulated industries, or dedicated localization-ops teams as a primary audience? *Check the "Should you use Dialect?" list in [README.md](../README.md) first.*

<!-- If any of the above is "yes", explain why in the Summary and tag a maintainer. -->
