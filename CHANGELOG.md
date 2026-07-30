# Changelog

All notable changes to the Dialect CLI are tracked here.

## [Unreleased]

## 1.2.0

Field-hardening release. Two projects and four feedback rounds put every
command through real use, and this is what came back: a `sync` that cannot
silently delete your strings, a `check` that can tell you so before you start,
`lock` / `accept` as first-class review gestures, and a website joining the
Flutter app and the backend as a consumer of one canonical source.

**Breaking:** `lock` and `accept` take a set of keys, so the trailing positional
locale moved to `--locale` (`dialect lock brand --locale vi`). Passing one
positionally reports the migration by name. The `icu-json` / `flat-json` output
contracts are unchanged.

### Added — `check` reports output drift, so it can answer "can sync run?"

- New warning rule **`output_drift`**: a generated output holds keys the source
  does not, which is exactly the condition `dialect sync` refuses on.
- `check` previously read `dialect/source` + `dialect/translations` and nothing
  else, so this was invisible to it. The prescribed order is
  `check --fix → sync → check`, which meant a repo carrying orphans reported
  **clean** through the first command, stayed clean through every edit made
  after it, and refused at the last step — on a condition that was already true
  before any of that work began. Nothing had to be redone; half an hour passed
  between knowable and known.
- It is a warning, not an error: orphans are strings in the wrong file, and
  everything still builds. `--strict` promotes it, which is where a pipeline
  that regenerates outputs wants to meet it. The fix is never automatic —
  choosing between `sync --adopt` and `sync --prune` is a data-loss decision
  that belongs to a person.
- The scan itself moved to `lib/project/output_scan.dart`, so `sync` and
  `check` answer this question from one implementation.

### Changed — `lock` and `accept` take a set of keys

- Both are the same gesture ("a human reviewed this") and both took exactly one
  key, which is the wrong unit: hand-authored copy arrives as a page, a screen,
  a namespace. Blessing one About page cost a 13-iteration shell loop.
- Both now accept any number of keys, plus `--namespace <name>` to take
  everything in a namespace: `dialect lock --namespace web`.
- **Breaking:** the trailing positional locale is now `--locale`. A variadic
  subject cannot also carry an optional trailing locale without guessing what a
  bare `vi` means. Passing one positionally says so by name rather than
  reporting "no such key `vi`", and the hints that print a runnable command
  (`source_equality`, `stale_translation`, `lock_integrity`) emit the new form.
- `--prefix webAbout` was considered and rejected: a prefix groups keys only
  when someone named them consistently, while a namespace is the grouping the
  source declares and sync already routes on.
- Both commands now write each ARB once per invocation instead of once per key.

### Changed — `sync --adopt` reports what it left for you to do

- The closing hint was unconditional, so a run where every adopted key came
  back with `namespace` + `description` still ended in a paragraph about adding
  metadata and re-running sync. The only way to establish "nothing to do" was to
  open the source and read the `@key` blocks by hand — and, inverted, one
  genuinely bare key could hide inside a list of twenty complete ones.
- It now reports the split: `All 16 keys came back with namespace +
  description` when there is nothing left, or the incomplete keys **by name**
  when there is. The warning became a work list, and silence became meaningful.
- The "then re-run `dialect sync`" instruction is gone from the complete case —
  that same invocation already regenerates every output.
- The refusal message names `--adopt` as the **one-time migration** for a
  project that learned to avoid `sync` back when it deleted keys. That habit is
  what produces the orphans, and such a project meets the refusal exactly once,
  with no way to know its own workaround is the cause.

### Changed — `sync` only warns about namespaces that reach NO platform

- The old warning fired **per platform**, listing every namespace that
  platform's allowlist excluded. On a project with one platform reading most of
  the source, that is useful. On a project with three — a Flutter app, a
  backend, a website — every platform excludes most namespaces *on purpose*, so
  a completely healthy `dialect sync` ended in three paragraphs of warnings
  naming twenty namespaces. Output that is noisy when nothing is wrong trains
  people to stop reading it, including on the day something is.
- It now warns once, about the thing that is actually a mistake: **a namespace
  no configured platform claims**, whose keys are therefore generated nowhere.
  Each is listed with how many keys it strands.

  ```
  ⚠ 1 namespace(s) reach no platform, so their keys are emitted nowhere:
      landing  —  43 key(s)
    hint: add each one to a `platforms.<p>.namespaces` list in dialect.yaml, …
  ```

- Coverage is judged across **every configured platform**, not just the ones a
  given run touched, so `dialect sync --platform backend` no longer calls the
  app's namespaces homeless.
- Found by dogfooding: Stepo's source now feeds a Flutter app, an ASP.NET
  backend, and a SvelteKit website. The old warning had no test coverage at
  all, which is how it shipped; the new behaviour has four tests.

### Documented — a web front end is a supported consumer

- [`docs/platforms-frontend.md`](docs/platforms-frontend.md) gained a
  **JavaScript / TypeScript web** section. A SvelteKit / Next / Nuxt front end
  reads `icu-json` directly; there is no adapter and there will not be one.
  It covers the `Intl.PluralRules` renderer, deriving compile-time key safety
  from `keyof typeof en`, locale negotiation on an edge runtime, and the
  escaping contract for messages carrying inline tags.
- The 2026-05 scope notice said React/web was secondary because "i18next covers
  their needs". That is right for a *web-only* team and wrong for a Flutter-led
  team whose website is the third consumer of one source — the exact shape
  Dialect exists for. Corrected rather than left to be re-derived.
- **Web frameworks are struck from the v2.0+ sponsored-adapters list.** Verified
  unnecessary rather than deferred.

### Documented — long-form documents are not keys

- `templates/dialect.yaml`'s "What NOT to extract" list now names privacy
  policies, terms of service, community guidelines, licences, and changelogs.
  A document is a document: shredding one into keys produces meaningless key
  names, unreadable diffs, and clauses that drift between locales, and in a
  legal document a drifted clause is worse than no translation. The convention
  never said so, so an agent extracting a page of prose would have been
  following instructions.

### Added — `dialect lock` (pin a deliberate translation)

- **`dialect lock <key> [locale]`** marks a translation as human-approved and
  records what was approved, writing `locked: true` **and** the current
  `source_hash` as one gesture. That pair is what `lock_integrity` requires,
  and hand-editing `@key` blocks to produce it was the last routine manual
  touch in the workflow — in a file the CLI otherwise owns.
- The common case is a translation that is *deliberately identical* to the
  source (a brand name, an abbreviation, a borrowed term), which
  `source_equality` flags on every run otherwise. Sibling to `accept`:
  re-running on a locked-but-stale key re-locks it against the current
  source.
- `--remove` unlocks, keeping the hash so staleness is still tracked.
- The `source_equality` and `lock_integrity` hints now print the exact
  command, runnable straight from CI output.

### Added — `toolchain.min_version` (a pin that can actually fire)

- `dialect.yaml` gained a machine-readable floor, and **`dialect init` stamps
  the version it ran as**:

  ```yaml
  toolchain:
    min_version: 1.2.0
  ```

- The new `toolchain_version` check **fails when the binary on PATH is
  older**. Projects previously encoded this as a prose "pinned toolchain"
  comment, which is folklore: nobody re-derives it, it drifts from the binary
  it names, and it cannot fire. The CLI already knows its own version.
- Severity is **error**: running too old a binary can mean silent data loss
  (pre-1.2 `sync` deleted keys that lived only in generated output), and a
  warning is what scrolls past on the day it matters.
- Pre-release suffixes are ignored, so `1.2.0-dev` satisfies a `1.2.0` floor.
- Known ceiling, by construction: a binary older than the release that added
  this rule doesn't contain the rule, so it can't warn about itself. It
  guards against future skew, like npm's `engines`.

### Added — `dialect init` owns the whole gen-l10n wiring

- `init` already wrote `flutter: generate: true`, but left `l10n.yaml` to the
  agent — and `generate: true` without an existing `arb-dir` makes
  **`flutter pub get` fail**, which is the very next command anyone runs. The
  directory wasn't created until the first `dialect sync`, which can't happen
  until keys exist.
- `init` now writes `l10n.yaml` (with `arb-dir` read from
  `platforms.flutter.output`, so the two can't disagree) and seeds the
  template ARB with the same `commonExample` entry the source scaffold
  carries. `pub get` is green from minute one, and the seed is byte-identical
  to what the first `sync` writes — so it neither trips the orphan guard nor
  shows up as a phantom diff.
- An existing `l10n.yaml` is never touched.

### Changed — `glossary_exempt` can name specific terms

- `@key.glossary_exempt` now accepts a **list of term names** as well as
  `true`:

  ```jsonc
  "glossary_exempt": ["take", "sentence"]   // waive exactly these
  "glossary_exempt": true                    // waive every term (blunt)
  ```

- One string can use two locked terms non-literally for two different and
  both-correct reasons while still needing the rest of the glossary applied.
  The old all-or-nothing switch waived those too — losing real coverage on
  precisely the strings complex enough to need an exemption.
- It also makes waivers reviewable: `glossary_exempt: true` in a diff tells a
  reviewer nothing about *what* was waived. The check hint now names the
  specific term, copy-pasteable.
- `true` keeps its meaning; the API's `glossary_exempt` stays boolean and
  term-scoped waivers travel in a new `glossary_exempt_terms` field, so
  existing clients are unaffected.

### Added — `check --fix --no-stamp` (authoring pass)

- Normalizes formatting **without** stamping `source_hash` onto entries that
  lack one. The first `--fix` on a hand-written locale otherwise turns ~280
  reviewable lines of `"key": "value"` into ~1,300, because every key gains a
  `@key` block — burying the review of the one file whose content most
  deserves reading.
- It only *defers*: existing hashes are never removed, unstamped entries are
  *untracked* (not stale, so the check stays green), and the next plain
  `--fix` stamps them.
- `dialect/spec/source_hash.md` now records why hashes stay inline and a
  hash **sidecar was rejected** — it would make the ARB no longer
  self-describing and turn a one-time diff into permanent two-file drift
  risk.

### Added — size-aware translation (`width_budget` + `slots:`)

- **A key can now declare the UI slot it renders in, and translations that
  outgrow it are flagged.** Text expands when translated — "Edit profile"
  (12 chars) becomes Vietnamese "Chỉnh sửa trang cá nhân" (23) — which
  silently breaks a tight button. `length_ratio` cannot catch that: 1.9× sits
  well inside its smell band. What was missing is a budget tied to the
  *slot*.
- Opt in on the **source** `@key` with `"x-slot": "button"` (a policy named
  in the new `slots:` block of `dialect.yaml`) or a hard
  `"x-max-length": 10`. A slot sets `max_ratio` (stay within N× the source —
  "similar length", floored at `source + grace` so short labels like "Save"
  never false-trip) or `max_length` (an absolute cap for a real pixel slot).
- **Opt-in by construction:** a key with neither field is never checked, so
  body copy, legal text and long-form prose are never policed.
- The check also flags a **source** string that busts its own budget — the
  slot is too tight even in English, which no translation can fix.
- Severity is `warning`, and plain `--strict` does **not** promote it; like
  `length_ratio` it needs the explicit `--strict-length`, and it can be
  acked. A button running a few characters long is a nudge, not a build
  failure.
- The real leverage is up front: **`dialect translate` inlines the resolved
  budget into the work list**, so the agent produces the short faithful form
  the first time instead of discovering the overflow at check time.
- Length is measured on literal copy in Unicode code points, so ICU
  placeholder names never inflate the count.

### Added — `dialect accept` (re-bless a still-correct translation)

- **`dialect accept <key> [locale]`** re-stamps an existing translation's
  `source_hash` to the current source *without* re-translating it — the
  first-class "I reviewed this, it still holds" gesture for when only the
  English wording moved. With no `[locale]` it blesses every target locale
  that carries the key (a no-op for those already fresh). It never touches
  the value or the `locked` flag, and refuses to stamp a missing/empty
  translation (that's `missing_keys`/`empty_values` to resolve). There is
  deliberately no automatic byte-identical re-stamp: an unchanged
  translation says nothing about whether it still matches the changed
  English. Replaces the old manual recovery (hand-delete the stale
  `@key.source_hash` block, then `check --fix`). The `stale_translation`
  hint now names this path.

### Fixed — empty `source_hash` is treated as absent, not stale

- A translation written by hand naturally carries `"source_hash": ""`.
  That empty string is never a real prior hash, so it's now normalized to
  "not yet stamped": `check` no longer flags it stale, and `check --fix`
  stamps the real hash — instead of sending an agent down the
  hand-compute-the-hash path.

### Fixed — glossary no longer fires on a placeholder-only term

- The glossary check (and the `translate` worklist) scan only the **literal
  copy** of a source string now: a term that appears solely as an ICU
  placeholder name — e.g. `journey` in `"Step · {journey}"` — is no longer
  demanded in the translation. Plural/select branch copy is still scanned,
  so a term that is genuine copy inside a branch still enforces. Removes the
  need for a `glossary_exempt: true` escape hatch on placeholder-only keys.

### Fixed — `dialect sync` is non-destructive (data-loss guard)

- **`sync` no longer silently deletes keys that live only in the generated
  output.** A key added straight to `lib/l10n/app_en.arb` (bypassing the
  source) used to vanish on the next `sync` — it reported "wrote N files"
  and `check` stayed green while live strings were gone. Sync now scans the
  outputs for **orphan keys** (present in a generated file, absent from
  `dialect/source`), and refuses when regenerating would drop them: it
  writes nothing, lists them, and exits non-zero. `dialect sync --dry-run`
  reports the same drift, so CI catches a hand-edited output.
- **`dialect sync --adopt`** recovers orphans into the Dialect source — the
  English value *and* its `@key` metadata into `dialect/source`, plus any
  translated value that lived only in a translation output into
  `dialect/translations/<locale>.arb` (so nothing is lost on regenerate).
- **`dialect sync --prune`** is the explicit opt-in to delete orphans and
  regenerate without them. Pruning is never the default.

### Changed — the `translate` plan is more self-contained + safe-by-default

- The generated `.dialect/translate-plan.md` now **inlines each key's source
  string, its `description`/`context`, and any glossary terms detected in
  the source** (with the target-locale form), so an agent translates from
  the meaning without a second lookup into the source ARB.
- The plan's finalize step now explains sync is non-destructive and warns
  the agent **not** to reach for `--prune` to silence an orphan-drift error
  (that deletes strings) — surface it, or `--adopt` if the keys belong.

### Added — bundle format + `dialect publish` / `dialect pull` (v1.2)

- **`dialect-bundle/1` spec** (`dialect/spec/bundle.md`) — an immutable,
  content-addressed snapshot of a project's translations for an
  environment: a mutable channel head (`manifest.json`) pointing at an
  immutable `b/<bundle_version>/` directory of per-locale JSON + a manifest
  with SHA-256 integrity. The `bundle_version` is derived from content
  only, so re-publishing identical translations is a no-op. Same shape
  across local-only, self-host, and Cloud (v1.3 publishes it to R2).
- **`dialect publish <env>`** — builds the bundle (in the env's `icu-json`
  or `flat-json` format, honoring a namespace filter) and uploads it. The
  `local` (filesystem) target ships now; `--dry-run` previews. The `s3`
  target exits with a clear "not yet — use local + your own sync" message
  (next slice).
- **`dialect pull <env>`** — fetches the published bundle, **verifies each
  locale file's SHA-256** (aborts on mismatch — corrupt data never reaches
  a deploy), and writes the per-locale JSON into the env's `output` dir.
  For CI deploy scripts. Does not touch the canonical ARBs.
- New `publish:` block in `dialect.yaml` (per-env `target` / `path` /
  `bucket` / `format` / `namespaces` / `manifest_url` / `output`).

## 1.1.0

Backend sync lands — the cross-stack thesis is real. One canonical source
now syncs to Flutter ARB *and* backend JSON, the stale-translation loop
closes the change-half, and `dialect translate` ships.

### Added — stale-translation tracking (the change-half of the loop)

- **Every translation now records `@key.source_hash`** — the version of the
  English source it was written against. `dialect check --fix` stamps it
  onto unlocked translations (never overwriting an existing one, so
  staleness survives); the dashboard stamps it at lock/edit time. When the
  source later changes, the hash no longer matches and the translation is
  **stale** — surfaced for *all* translations now, not just locked ones.
- **New `stale_translation` check rule** — warns (promotes under `--strict`,
  so CI gates on it) when a translation's source changed since it was
  written. Resolved by re-translating (`dialect translate` refreshes the
  hash) or locking the value if it's still correct. `dialect status`'s
  `Stale` column now counts unlocked staleness too.
- **`dialect translate`** gained a **Stale (re-translate)** bucket for
  unlocked-stale keys, alongside Missing and the review-only Stale (locked).
- Provenance is committed in the ARB and travels with the value — the same
  contract maps to a Postgres column carried by `push`/`pull` in Cloud
  (v1.3). See `dialect/spec/source_hash.md`.

### Fixed

- **`dialect check --fix` no longer wipes locks.** It previously rebuilt
  every translation as bare key/value, silently destroying dashboard-written
  `locked` + `source_hash` on the next run. `--fix` now strips only
  *descriptive* metadata (namespace/description/placeholders) and preserves
  *state* metadata (locked, source_hash).

### Changed

- **`dialect init` scaffolding surfaces the new capabilities.** The
  generated `dialect.yaml` now includes a commented `backend:` platform
  example (icu-json vs flat-json explained) and a `dialect translate` tip;
  the `AGENTS.md` section mentions `translate` and cross-stack sync — so
  backend JSON output and the translate flow are discoverable after init.

### Added — backend sync (the cross-stack core)

- **`icu-json` and `flat-json` adapters.** `dialect sync` now emits backend
  JSON, not just Flutter ARB. `icu-json` preserves ICU plural/select
  expressions verbatim; `flat-json` collapses them to the `other` branch
  for stacks without an ICU runtime. Both honor the same `@key.namespace`
  filter as the ARB path, write `<locale>.json` with sorted keys and a
  trailing newline, and are idempotent. Output matches the locked specs at
  `dialect/spec/icu-json.md` and `dialect/spec/flat-json.md`. This is the
  cross-stack value prop — one canonical source, Flutter + backend in sync.
- **`flat-json` lossy-event hint.** When a `flat-json` platform strips
  plurals, sync prints one info line listing the affected keys and points
  at `icu-json` for locale-correct plurals.
- **`dialect sync` ergonomics.** `--dry-run` previews which files would
  change without writing (exits non-zero if any are out of date — a CI
  gate that committed outputs match the source); `--platform <name>` syncs
  a single configured platform.

### Added — soft-mode acknowledgements (`dialect check --ack`)

- **`.dialect/state.json` + `dialect check --ack <rule>:<locale>:<key>`.**
  Dismiss an intentional soft warning (e.g. "Email" stays "Email" in
  Vietnamese) without flipping CI to `--strict`. The ack is fingerprinted
  with the source/translation value at ack-time per
  `dialect/spec/state.md`; if that value later changes, the warning
  re-fires and the report flags the ack as stale (`⚠ stale-ack …`).
  Structural rules are rejected — those are correctness failures, not
  heuristics. `--note` records a justification; `check` prints how many
  issues were hidden by acks.

### Added — `dialect translate`

- **`dialect translate`** (AI-pointer flow). Writes
  `.dialect/translate-plan.md` with a **computed work list**: which keys are
  missing per locale (in source order) and which locked translations have
  gone stale (source changed since the lock). Stale locks are flagged
  review-only — the plan never instructs the agent to overwrite a human
  lock. `--auto` (direct LLM call) is reserved and currently exits with a
  clear "use the AI-pointer flow" message rather than silently no-opping.

## 1.0.4

Release-pipeline-only patch. Fixes the pub.dev publish step that hung
on both 1.0.2 and 1.0.3 even after publisher OIDC trust was configured.

Root cause: `dart pub publish --force` run via Flutter-bundled Dart
did not auto-detect the GitHub Actions OIDC environment and silently
fell back to the interactive Google OAuth device-flow ("In a web
browser, go to https://accounts.google.com/o/oauth2/auth?…"). With no
stdin in CI, the job hangs until cancelled.

Fix: explicit OIDC mint + `dart pub token add https://pub.dev`
ahead of `dart pub publish`. The token is requested with the
`https://pub.dev` audience via `ACTIONS_ID_TOKEN_REQUEST_URL`, so
pub.dev's publisher-side OIDC trust validates the source repo, tag
pattern, and environment as expected.

No CLI, convention, or wire-format changes.

## 1.0.3

Three threads land together: an agent-pilot bug pass against the `init`
flow (B1–B4), the dashboard UX overhaul, and the example-project split.
Also the second pub.dev publishing attempt now that publisher OIDC trust
is configured, and a CI scoping fix that surfaced after the v1.0.2 push.

### Fixed — init plan bugs from Opus 4.7's pilot run

These four blockers turned `dialect init` from "AI follows the plan and
the app builds" into "AI follows the plan and `flutter pub get` errors"
or "translations silently drop". Full pilot feedback under
`docs/feedback/`.

- **B1 — modern AppLocalizations import path.** The init plan was
  writing the legacy synthetic-package import
  (`package:flutter_gen/gen_l10n/app_localizations.dart`). Modern Flutter
  defaults to `synthetic-package: false`, where the import is
  `package:<pubspec_name>/l10n/app_localizations.dart`. The plan now
  reads the example's pubspec name and renders the correct import; a
  new `PUBSPEC_NAME` token threads through plan rendering.
- **B2 — `intl` pin conflict on modern Flutter.** The init plan pinned
  `intl: ^0.19.0`, which fought `flutter_localizations`' own `intl`
  constraint on Flutter 3.41+ SDKs and broke `flutter pub get`. Now
  `intl: any`, with a short note in the plan explaining why.
- **B3 — `dialect sync` dropping every translated key under a
  namespace filter.** The adapter read namespace metadata from
  *translation* entries, but by convention only the source ARB carries
  `@key` blocks. With a namespace filter set in `platforms.flutter`,
  the filter rejected everything. Now the filter joins translation
  keys against source-ARB metadata. The adapter API gains a required
  `source: ArbFile?` param when `isSource: false`.
- **B4 — `dialect sync --force`.** Added as an explicit escape hatch
  for rewriting outputs regardless of content match. (The original
  B4 repro was a downstream symptom of B3 and is resolved by the B3
  fix; `--force` handles the remaining "rewrite anyway" cases.)

Seven follow-ups (B5 + F1–F6) filed as issues #1–#7.

### Changed — example project layout

- `example/` → `examples/{before,after}/` — two sister Flutter apps.
  `before/` is bare with hardcoded English; `after/` is a pure clone
  used as the target for end-to-end `dialect init` testing. The user's
  AI agent populates `after/dialect/`, `l10n.yaml`, and AppLocalizations
  callsites when run against the cloned starting state.
- Canonical Dialect fixture (used by `check` / `status` / roundtrip
  tests) moved to `test/fixtures/canonical/dialect/`. Tests now point
  there instead of `example/dialect/`, decoupling them from the demo
  apps.
- Multi-model validation harness moved to `examples/_validation/`,
  reading from `examples/before/lib/`. `INSTRUCTIONS.md` and the
  chat-only fallback updated for the new paths.

### Changed — dashboard

- **Editor UX**: replaced blur-to-save with an `EntryEditor` panel that
  has explicit Save / Cancel / Revert, plus Copy-from-source, Clear,
  and lock-to-source. Placeholder + character-count hints inline.
- **Visual refresh**: dark-mode support, status pills
  (missing / stale / locked), per-locale coverage bars in the sidebar.
- **Navigation**: keyboard shortcuts for next-missing / next-stale
  jumps, multi-locale sidebar selection.

### Fixed — release-pipeline / CI

- **CI** — `dart format --set-exit-if-changed` now scopes to
  `bin lib test tool` instead of `.`. The `examples/*/` subpackages
  have their own pubspec + Flutter version and are verified
  independently — formatting them from the root crosses Flutter-SDK
  boundaries and trips version-sensitive formatter rules (the
  Flutter-3.41 vs Flutter-3.44 formatter delta surfaced on the v1.0.2
  push).
- **Format** — ran `dart format` against the dialect package itself
  to pick up two pending whitespace adjustments in
  `lib/commands/sync.dart` and `test/adapters/arb_adapter_test.dart`.
- **pub.dev** — the v1.0.2 publish hung because the publisher had not
  enabled OIDC trust for `ChauCM/dialect`. That's now configured;
  v1.0.3 re-attempts the publish through the same workflow path.

## 1.0.2

Release-pipeline-only patch. The 1.0.0 and 1.0.1 tags never produced a
GitHub release: `linux-arm64` builds failed because Flutter doesn't
ship an arm64 Linux SDK that `subosito/flutter-action` can resolve, and
`macos-13` (Intel) runners stayed queued for 30–45 minutes. This release
drops both platforms from the matrix.

- **Pre-built binaries** now ship for `macos-arm64`, `linux-x64`, and
  `windows-x64` only. Intel macOS and Linux ARM64 users build from
  source — see the new "Build from source" section in the README.
- **Homebrew formula** errors clearly (`brew install` → `odie`) on
  Intel Mac and Linux ARM64 instead of pretending to install.
- **`install.sh`** refuses unsupported targets with a pointer to the
  build-from-source instructions instead of 404'ing on a missing
  artifact mid-script.
- No CLI, convention, or wire-format changes.

## 1.0.1

Documentation + tooling polish on top of 1.0.0. No CLI behavior
or convention changes — the wire format and Dart APIs are
identical to 1.0.0.

- README rewritten to lead with the chat-first DX. New project:
  one chat message (`run dialect init and follow the instructions`).
  Ongoing work: plain English ("translate the new screen") backed
  by the AGENTS.md the agent installer drops at the project root.
  Manual CLI commands collapsed behind `<details>` blocks as
  optional advanced touchpoints.
- README teaser block (the elevator-pitch Dev/AI dialogue) updated
  to the natural-language flow that lands after `dialect init`.
- `dart format` applied to the nine M3.5 files I'd missed in the
  1.0.0 commit. CI's `dart format --set-exit-if-changed` check is
  now clean.

## 1.0.0

First stable release.

The shipping convention: **flat camelCase keys** (`checkoutBookNow`)
with logical grouping in `@key.namespace` metadata. This is what
`flutter gen-l10n` requires — every source key becomes a method
on `AppLocalizations` after sync. No mangling, no impedance
mismatch with Flutter's default localization tool.

Onboarding collapses to **one CLI command + one chat message**:

  $ dialect init
  (then in your AI agent:)
  > run dialect init and follow the instructions

`dialect init` scaffolds, detects the project type, writes a
two-phase `.dialect/init-plan.md` (the AI's playbook), and
writes/updates `AGENTS.md` (or appends to `CLAUDE.md` if that's
what the project already has). Re-running `dialect init` is
idempotent — refreshes the plan without clobbering the scaffold.

Phase 2 of the init plan has a single sizing rule: ≤ 50
candidate strings → AI extracts + translates in one chat turn;
> 50 → AI extracts only, then stops for the developer to
sanity-check key names before the long translation step.

Convention + check rules:
- `ArbMetadata.namespace` is a first-class field on every
  source key. The parser reads it, the writer emits it first
  in the metadata block, the ARB adapter filters by it.
- Two new structural check rules: `key_format` (rejects
  non-Dart-identifier keys with a specific hint for the
  pre-1.0 dotted shape) and `namespace_required` (source
  keys must declare `@key.namespace`).
- All in-repo ARBs (live `example/`, validation seed) re-keyed
  to the new shape; `example/_validation/INSTRUCTIONS.md`
  refreshed for the new chat-message default.

Distribution: Pub + Homebrew + curl + GitHub Action, all wired
in the 1.0.0-rc.* series and now tagged as 1.0.0.

The brainstorm-phase planning docs, research, references, and
spikes moved out of this repo and into the archived brainstorm
repo at `/Users/chaucao/Documents/github/brainstorm/dialect`.
The shipping repo carries only the user-facing docs, the CLI,
the example app, and the validation harness.

## 1.0.0-rc.3

UX pivot: the AI now owns the full CLI chain.

Before: import/describe plan files told the AI "do not run
`dialect sync` or `dialect translate` — those are the developer's
calls." The developer had to chain `check --fix` → `sync` → `check`
themselves after every AI run. That broke the 2-step promise in
the README.

After: the plan templates instruct the AI to run
`dialect check --fix && dialect sync && dialect check` as the
final step of every import / describe job and report the result.
The 2-step happy path becomes:
  1. `dialect init`
  2. Ask the AI to follow `dialect/dialect.yaml`. The AI extracts,
     translates, normalizes, syncs, and validates. Reports back.

Terminal `dialect check` / `sync` / `status` / `serve` are still
there for any step the dev wants to inspect or drive manually —
they're now framed as advanced touchpoints rather than required
steps. README's walkthrough collapses to the 2-step flow with
manual commands tucked under collapsible `<details>` blocks.

Code surface: zero CLI changes. Just `templates/import_plan.md`,
`templates/describe_plan.md`, baked Dart constants regenerated by
`tool/sync_templates.dart`, two new positive assertions in the
import/describe tests, and the README rewrite.

## 1.0.0-rc.2

Re-cut of `1.0.0-rc.1` with the Flutter-setup fix applied to
`.github/workflows/release.yml` (same fix CI got — `dart pub get`
recurses into `example/` which needs Flutter, not bare Dart).
Bundles the README rewrite that leads with the Lokalise-replacement
positioning and a real day-1 walkthrough instead of a summary.

## 1.0.0-rc.1

First release candidate — feature-complete, dogfooding through the
distribution pipeline (M11). No source changes since `0.1.0-dev`
beyond the version bump; this RC's job is to exercise
`.github/workflows/release.yml` end-to-end before tagging `v1.0.0`.
**Failed at the `dart pub get` step on every matrix runner**
(Flutter not installed); fixed in rc.2.

## 0.1.0-dev

The pre-1.0 development line. Every milestone from M0 (convention
validation) through M11 (distribution pipeline) is rolled into
`0.1.0-dev` until the `v1.0.0` tag promotes the spec contracts to
stable. Detailed per-milestone notes follow.

### Added
- **M11.** Distribution pipeline — four channels (Docker + Scoop
  dropped per scope decision).
  - **`install.sh`** at the repo root. POSIX `sh`, OS/arch detection
    (`macos-arm64`, `macos-x64`, `linux-x64`, `linux-arm64`), version
    pinning via `DIALECT_VERSION`, install location via
    `DIALECT_INSTALL_DIR` (default `~/.local/bin`), SHA-256 checksum
    verification against the release's `SHA256SUMS` asset. Refuses
    Windows with a pointer to the GitHub release zip. Hosted at
    `https://dialect.tools/install.sh`; also published as a release
    asset so the GitHub URL is a stable fallback.
  - **`.github/workflows/release.yml`** — tag-driven (`v*`) matrix
    build across `macos-latest` (arm64), `macos-13` (Intel x64),
    `ubuntu-latest` (x64), `ubuntu-24.04-arm` (arm64), and
    `windows-latest`. Each runner: pnpm install + build the
    dashboard, `tool/build_dashboard.dart --no-pnpm` to bake the
    SPA, `dart compile exe`, tarball/zip + SHA-256.
    Aggregate job composes `SHA256SUMS`, attaches every artifact +
    `install.sh` to the GitHub release. Separate `pub` job
    publishes to pub.dev via OIDC (no secret token). Separate
    `homebrew` job renders the formula from
    `homebrew/dialect.rb.tmpl` and opens a bump-PR against
    `ChauCM/homebrew-tap` (skipped for prereleases —
    `v1.0.0-rc.1` etc. don't ship to Homebrew).
  - **`action.yml`** at the repo root — composite GitHub Action.
    `uses: ChauCM/dialect@v1` with `args:` (default
    `check --strict`), `version:` (default `latest`), and
    `working-directory:` inputs. Installs via the same
    `install.sh` script so the action and the curl-installer share
    one code path.
  - **`homebrew/dialect.rb.tmpl`** — formula template; per-target
    `{{*_SHA256}}` and `{{VERSION}}` placeholders. Branched by
    `Hardware::CPU.arm?` so a single formula covers macOS arm64,
    macOS x64, linux arm64, linux x64.
  - **`tool/render_homebrew_formula.dart`** — reads the template,
    fetches `SHA256SUMS` from the GitHub release for a tag, fills
    in every placeholder, aborts non-zero if any per-target hash
    is missing (so the bump-PR can't ship a half-rendered formula).
  - **`LICENSE.md` → `LICENSE`** per pub.dev convention.
  - **`CHANGELOG.md`** gains a top-level `0.1.0-dev` heading per
    pub.dev convention so the next `dart pub publish --dry-run` is
    down from 4 warnings to the single deferred `docs/ → doc/`
    rename note.
  - **Dropped from the original 6-channel plan**: Docker (no
    expected adoption signal yet; can re-add post-v1.0 if users
    ask) and Scoop (Windows package manager; Windows users get
    binaries via the GitHub release zip until there's signal).

- **M10.** Svelte dashboard SPA + `dialect serve`.
  - **Dart Shelf server** at `lib/server/server.dart` binds
    `localhost:4077` by default (configurable via `--port`/`--host`).
    Each request reloads the project from disk so external ARB edits
    are visible immediately — the project is tiny, I/O is cheap, and
    it removes the stale-cache foot-gun.
  - **REST API** per `docs/architecture.md` § REST API:
    - `GET /api/config` — parsed `dialect.yaml` plus the resolved
      project name.
    - `GET /api/strings?locale=<loc>` — every source key with the
      matching translation entry. Includes `description`, `context`,
      `placeholders`, `locked`, `glossary_exempt`, `source_hash`,
      and computed `stale` + `missing` flags.
    - `PUT /api/strings/<key>` — body `{ locale, value, locked?,
      glossary_exempt? }`. Writes back through `ArbWriter`
      (canonical formatting). Locking writes `@key.source_hash` per
      `dialect/spec/source_hash.md`; unlocking clears it. Empty
      metadata blocks are dropped (no `@key: {}` noise on
      translation files).
    - `GET /api/glossary` — parsed `glossary.yaml`.
    - `GET /api/status` — reuses the M6 `computeStatus` math
      byte-for-byte, so the dashboard footer and the CLI agree.
    - `OPTIONS` preflight + permissive CORS so the SPA can run
      under `pnpm dev` against the Dart server during dashboard
      development.
    - JSON 404 for unknown `/api/*` paths (never falls through to
      the SPA HTML handler); JSON 500 for uncaught exceptions.
  - **Svelte 5 SPA** (`dashboard/`, built with Vite, package
    manager pinned to **pnpm**):
    - `App.svelte` — locale switcher + filter sidebar + translation
      table + coverage footer.
    - `lib/TranslationTable.svelte` — keyboard-driven inline editing
      (Enter to save, Esc to cancel, blur saves, optimistic refresh
      of strings + status after each PUT).
    - `lib/GlossaryHighlight.svelte` — whole-word glossary
      highlighting of the source string with the canonical-translation
      tooltip.
    - `lib/LockToggle.svelte` — pin/lock control wired through the
      `locked` field on PUT.
    - `lib/FilterPanel.svelte` — missing/locked/stale toggles,
      namespace radio group, search box.
    - `lib/CoverageFooter.svelte` — coverage % + missing/stale/locked
      counts from `/api/status`.
    - `lib/api.ts` — typed `fetchConfig`/`fetchStrings`/`fetchGlossary`
      /`fetchStatus`/`putString` wrappers.
  - **Static-asset embedding.** `tool/build_dashboard.dart` walks
    `dashboard/dist/` after `pnpm build` and emits
    `lib/server/embedded_assets.g.dart` — a single
    `const Map<String, List<int>>` from forward-slash paths to file
    bytes. `dart compile exe bin/dialect.dart -o build/dialect`
    produces an 8.1 MB self-contained binary that serves the SPA
    with **zero `node_modules` on disk at runtime**. Generator
    supports `--no-pnpm` (CI pre-builds) and `--check` (drift gate).
  - **Empty-bundle fallback.** When the generator hasn't run on
    this checkout, `/` serves a minimal "Dashboard not bundled
    yet" HTML page that names the exact command to bake it in. The
    REST API stays live so backend work can proceed without the
    SPA build.
  - **Real implementation of `dialect serve`** (was a stub).
    `--port`/`--host` flags, project-load preflight surfaces "no
    project" as exit 66 before binding the port, SIGINT clean
    shutdown.
  - **`ArbMetadata.copyWith`** — new helper with a sentinel for
    `sourceHash` so callers can explicitly clear the field (unlock)
    without colliding with the "leave it alone" default. Powers the
    PUT mutation path.
  - 13 new server route tests (now 178 total). Real E2E verified
    against `build/dialect serve example/`: PUT writes
    `Reservar AHORA` + `@key.source_hash` to `es.arb` on disk;
    unlock reverts both.

### Added
- **M9.** Stable on-disk-contract spec docs under `dialect/spec/`.
  - **`icu-json.md`** — backend JSON output that preserves ICU
    plural/select expressions byte-identically. Flat keys (not nested
    objects), one file per locale, UTF-8 NFC, 2-space LF, sorted.
    Aligned with `Dialect.AspNetCore` (v1.1) and the third-party
    backend libraries documented in `docs/platforms-backend.md`.
  - **`flat-json.md`** — sibling format that strips ICU
    plural/select/selectordinal to a single plain string by taking
    the `other` branch and recursively stripping nested expressions.
    Documents the loss-of-information trade-off and the `info` hint
    `dialect sync` emits when a project's source uses plurals and
    `flat-json` is selected.
  - **`state.md`** — `.dialect/state.json` shape for soft-mode
    `dialect check` acknowledgements (decision 9 in the plan).
    Per-issue acks keyed by `<rule>:<locale>:<key>`, fingerprinted
    with the source/translation hash at ack-time so edits resurface
    the warning. Structural rules are explicitly NOT ack-able (those
    are correctness failures, not heuristics).
  - All three carry the same status header as `source_hash.md`:
    v1.0 stable contract, breaking changes require a major bump.
  - README.md gains a "Stable on-disk contracts" sub-section linking
    every spec — backend integrators land on the contract before they
    write a single line of glue code.
  - **Blocks the v1.0.0 tag per the plan.** The
    `Dialect.AspNetCore` NuGet (v1.1) depends on a stable `icu-json`
    contract; shipping v1.0 without versioned specs would cost us
    users at the first breaking change.

### Added
- **M8.** `dialect check` semantic heuristics — four new rules layered on
  the M4 `Rule` interface, runner, and report.
  - **`source_equality`** (warning) — flags translations identical to
    the source. Filters short / symbol-only values; honors
    `@key.locked: true` as the explicit dismissal.
  - **`length_ratio`** (warning) — flags translations whose char count
    is outside `[min, max] * source.length`. Default band
    `[0.3, 2.5]`. Per-locale overrides via `length_ratio:` in
    `dialect.yaml`. Source values shorter than 8 chars skip the
    check (too noisy on "OK"/"Hi"-class strings). Reports the actual
    ratio in the message.
  - **`untranslated_english`** (warning) — flags translation values
    containing a conservative whole-word English function word
    (`the/and/with/this/that/you`) that isn't carried over from the
    source. Bias: under-flag rather than wrongly flag.
  - **`glossary`** (warning) — for every source value containing a
    glossary `term:` (whole-word, case-insensitive), each target
    translation must contain a recognizable prefix of the canonical
    `translations.<locale>`. Suffix-inflection tolerance baked in
    (drops last 2 chars when len > 4, so "Reservar" matches
    "Reserva"/"Reservamos"). Honors `@key.glossary_exempt: true` on
    the source entry — the documented escape hatch for non-literal
    uses.
- **`lib/glossary/glossary_loader.dart`** — typed loader for
  `dialect/glossary.yaml`. Empty when file absent (no error); throws
  `FormatException` on malformed YAML. Loaded once at
  `DialectProject.load` and exposed as `project.glossary` so every
  rule reads from the same in-memory snapshot.
- **`--strict-length` plumbing.** `report.dart` learned to honor the
  flag independently of `--strict`: under bare `--strict`, every
  warning promotes to error except `length_ratio` (length ratios are
  noisy enough that a blanket CI gate produces too many false
  positives). `--strict-length` is the explicit opt-in.
- **CHANGELOG note for example/ polish.** Running `dialect check` on
  the canonical `example/` now surfaces 7 real semantic warnings
  (source-equality on `Total` / `Email` carryovers; glossary misses
  in ar; length-ratio edge cases for ja/ar). Soft mode exits 0, so
  the integration test stays green — but these are real signals the
  demo polish should address (lock the legit carryovers, widen the
  per-locale length bands).

### Added
- **M7.** `dialect import` + `dialect describe` — AI-pointer flow.
  - `dialect import --from <fmt> --path <path>` writes
    `.dialect/import-plan.md`. `dialect describe [--path <path>]`
    writes `.dialect/describe-plan.md`. Dialect itself never opens
    `.dart`/`.kt`/`.swift`/`.cs` files; the plan tells the user's AI
    where to look. CLAUDE.md §3.1 made literal.
  - Plan-file content is the load-bearing product surface. Each plan
    is self-contained — it inlines the load-bearing convention rules
    (key style, namespaces, "what NOT to extract", placeholder
    preservation, ICU plural shape, glossary application, hard
    guardrails) so a stock AI agent doesn't need follow-up prompting,
    and points at `dialect/dialect.yaml` as the canonical source if
    anything conflicts.
  - Templates live at `templates/import_plan.md` and
    `templates/describe_plan.md` (reviewable in PRs as Markdown);
    `tool/sync_templates.dart` bakes them into
    `lib/templates/{import,describe}_plan_md.dart`. Runtime token
    substitution via `lib/templates/plan_render.dart`. Tokens:
    `{{FROM}}`, `{{PATH}}`, `{{SOURCE_LOCALE}}`, `{{TARGET_LOCALES}}`,
    `{{PROJECT_NAME}}` (reads `project.name` from `dialect.yaml` with
    a friendly fallback), `{{NAMESPACES}}` (sorted union across
    platforms), `{{GENERATED_AT}}` (ISO 8601 UTC). Unknown tokens are
    left in place so seed-file typos are loud, not silent.
  - Plan files overwrite on every run — `.dialect/` is gitignored
    ephemera per M3, not durable state.
  - Exit codes consistent with `status`/`check`: 0 success / 64
    usage (missing `--path` on import, unknown `--from`) / 65
    malformed `dialect.yaml` / 66 no project.

### Added
- **M6.** `dialect status` — per-locale coverage table.
  - Columns: `Locale`, `Coverage`, `Stale`, `New`, `Locked`. Output via
    a Unicode box-drawing table (`lib/render/table.dart`).
  - `Coverage` = `(translated keys) / (source keys)`. `New` = source
    keys missing from the translation. `Locked` = entries with
    `@key.locked: true`. `Stale` = locked entries whose stored
    `@key.source_hash` no longer matches the current source value's
    hash.
- **`@key.source_hash` spec** at `dialect/spec/source_hash.md`. SHA-256
  of the NFC-normalized source value, truncated to 16 lowercase hex
  chars. Written by the dashboard at lock-time (M10); read by status,
  the dashboard's stale indicator, and `dialect translate --skip-locked`
  (M8+). Hashing the value only — not description or placeholders —
  so a description edit doesn't invalidate locked translations.
- **`lib/arb/source_hash.dart`** — `computeSourceHash` implementing the
  spec. 6 tests including a locked-in fixture so future implementations
  can't silently change the on-disk fingerprint format.
- **`lib/render/table.dart`** — generic Unicode-table renderer.
  Right-aligns numeric data columns, left-aligns text and the header.
  Zero deps. 5 tests.

### Added
- **M5.** `dialect sync` — ARB-passthrough adapter.
  - Walks `platforms:` in `dialect.yaml`. For each platform with
    `format: arb`, writes `<output>/app_<locale>.arb` files (Flutter's
    `gen_l10n` convention).
  - Source ARB output keeps `@key` metadata; translation outputs strip
    metadata per the convention.
  - Namespace filter: keys whose prefix (before the first `.`) isn't in
    `platforms.<p>.namespaces` are dropped from that platform's output.
    Empty namespaces list = no filtering.
  - Output paths resolved against the **project root** (not cwd), so
    `dialect sync /path/to/proj` and `cd /path/to/proj && dialect sync`
    write identical bytes to the same locations.
  - **Idempotent**: re-running `sync` with no changes does not touch
    any files (mtime preserved). `_maybeWrite` skips writes when the
    desired bytes already match disk.
  - **Sync does not auto-fix the input ARBs.** Run `dialect check --fix`
    separately to normalize sources; sync produces canonical output
    regardless (because it goes through `ArbWriter`).
  - Non-`arb` formats print a "lands in v1.1" hint and skip without
    erroring.
- **`DialectConfig.platforms`** parsing — typed `PlatformConfig`
  (`name`, `output`, `format`, `namespaces`). `length_ratio` and
  `project` blocks still flow through `extras` for M8.
- **`lib/adapters/arb_adapter.dart`** — `ArbAdapter.prepare`
  (filter + strip), `ArbAdapter.encode` (delegates to `ArbWriter`),
  `ArbAdapter.filenameFor` (the `app_<locale>.arb` convention; v1.1
  spec will make this configurable via `platforms.<p>.filename_pattern`).

### Added
- **M4.** `dialect check` — structural validation + `--fix` normalization.
  - **Five structural rules** under `lib/checks/structural/`: `missing_keys`,
    `placeholder_match`, `plural_categories`, `empty_values`,
    `orphan_metadata`. Each rule emits typed `Issue` objects with severity,
    locale, key, file path, line number, and a real soft-mode hint (not a
    stub). The `Rule` interface is shared with M8 semantic rules.
  - **CLDR table** (`lib/checks/cldr_categories.dart`) covers ~25 common
    locales; unknown locales emit a friendly warning rather than silently
    skipping.
  - **Position tracking** added to the parser: every top-level key gets a
    1-based line number (`ArbFile.entryLines`) via a regex post-pass over
    the source text. Powers `file:line` hints in the check report. Both
    `"key":` and `"@key":` lines are recorded so orphan metadata gets a
    position too.
  - **Project loader** (`lib/project/dialect_project.dart`) reads
    `dialect.yaml` + source ARB + every target translation. Minimal
    `DialectConfig` parser; M5 extends with `platforms` and
    `length_ratio`.
  - **`--fix` mode** re-emits every ARB through `ArbWriter`: sorts keys,
    hoists `@@locale`, places `@key` blocks correctly, strips translation
    metadata, drops orphans. Re-runs the check pass on the rewritten
    files so the exit code reflects post-fix state.
  - **Real-world fixture coverage**: the plural-categories rule uses
    `_validation/runs/{gpt-5-3,claude-post-patch}/dialect/translations/ar.arb`
    as the negative / positive fixtures (the M0+ Codex defect → live bug
    fixture, no synthetic mockery).
  - Exit codes: 0 clean / 1 errors / 64 usage / 65 malformed ARB or YAML
    / 66 no project. Soft mode exits 0 for warnings-only;`--strict`
    promotes everything to errors.

### Changed
- **M3 follow-up.** Three small fixes before M4 starts.
  - `templates/glossary.yaml` now ships with one example term + a
    "Replace or delete this entry" hint, the same pedagogical role as
    `common.example` in `source/en.arb`. Was effectively empty before.
  - SDK floor bumped from `^3.4.0` to `^3.11.0` (current stable Dart).
    Pre-1.0 policy: track current stable. Locks at "current + previous
    two minor SDK versions" at 1.0 launch. Policy documented in
    `planning/mvp-plan.md`.
  - `tool/sync_templates.dart` simplified — the `dart format` pipe
    workaround removed in favour of `// dart format off` directives in
    the generated source. The directive landed in Dart 3.7 and is now
    honored on every supported SDK.
- **v1.0.1 backlog** (flagged from M3 review, intentionally not blocking
  M4):
  - `dialect init --force` is whole-tree overwrite for the canonical
    files. A separate `--refresh` (write only missing files) is
    friendlier for users with customized `dialect.yaml`.
  - `project.name` could auto-detect from a sibling `pubspec.yaml`'s
    `name:` field, falling back to the directory basename. Currently
    everyone gets the placeholder "Your project".

### Added
- **M3.** `dialect init` — the first user-facing command.
  - Accepts an optional positional `[path]` argument (defaults to cwd).
  - `--force` overwrites an existing `dialect/` directory.
  - Writes `dialect/dialect.yaml`, `dialect/glossary.yaml`,
    `dialect/source/en.arb`; creates `dialect/translations/`.
  - Appends `.dialect/` to `.gitignore` (creates the file if missing,
    deduplicates if already present).
  - Exit codes: 0 success, 64 usage, 65 dialect/ exists w/o `--force`,
    66 target directory missing.
- **Templates pipeline.** Canonical seed YAML/ARB at repo-root
  `templates/`; `tool/sync_templates.dart` bakes them into Dart
  constants under `lib/templates/*.dart`. `--check` mode wired into CI
  so a hand-edited generated file fails the build. The generator pipes
  output through in-project `dart format` so the on-disk shape always
  matches what `dart format` would produce. 9 init tests in
  `test/commands/init_test.dart` (creation, byte-identical templates,
  .gitignore handling, --force, error cases).

### Changed
- **M2 hardening.** Pre-emptive fixes to the ARB substrate before M3 builds
  on it.
  - Parser preserves unknown `@@<name>` file-level metadata in
    `ArbFile.fileMetadata` (e.g. Flutter `gen_l10n`'s `@@last_modified`).
    Writer emits it after `@@locale` in sorted order. Prevents silent
    data loss on `dialect sync`.
  - Orphan `@key` blocks (no matching key/value) preserved in
    `ArbFile.orphanMetadata` so M4 can surface them as structural errors
    without re-reading raw JSON. Writer skips orphans by construction —
    `dialect check --fix` strips them implicitly.
  - `example/dialect/source/en.arb` synced with the canonical 30-key
    extract from `_validation/runs/claude-post-patch/`. Matches the
    translation files now.
  - `arb_roundtrip_test.dart` resolves the seed via `test/_support/repo_root.dart`
    instead of a `cwd`-relative path.
  - Removed unused `intl: ^0.20.2` dependency.
- **Tooling.** `tool/sync_version.dart` keeps `lib/version.dart` in lock-
  step with `pubspec.yaml`'s `version:` field. `--check` mode runs in CI
  so a forgotten sync fails the build. Stricter hand-picked lints
  (`unawaited_futures`, `avoid_dynamic_calls`, `prefer_relative_imports`,
  `directives_ordering`, `prefer_final_locals`, `cancel_subscriptions`,
  `close_sinks`) layered on top of `package:lints/recommended.yaml`.
- **CI.** `.github/workflows/ci.yml` runs `dart pub get`, version-sync
  `--check`, `dart format --set-exit-if-changed`, `dart analyze
  --fatal-infos --fatal-warnings`, and `dart test` on every push and PR.
- **Docs.** `planning/mvp-plan.md` updated to reflect that
  `intl_translation` is deprecated and Dialect ships a focused ICU
  scanner; future agents reading the plan won't try to "fix" the code
  by ripping out the scanner.

### Added
- **M2.** ARB read/write + ICU detection (`lib/arb/`).
  - `arb_file.dart`: typed model with `description`, `context`, `placeholders`,
    `locked`, `glossary_exempt`, `source_hash`, plus extras pass-through.
  - `arb_parser.dart`: reads ARB JSON; NFC-normalizes all string values
    (`unorm_dart`) so Vietnamese NFD vs NFC inputs hash identically.
  - `arb_writer.dart`: emits canonical ARB JSON matching the seed file
    byte-for-byte (sorted keys, `@@locale` first, `@key` after its key,
    blank-line separators).
  - `icu_message.dart`: focused scanner exposing
    `extractPlaceholders`, `extractPluralCategories`, `hasExpressions`.
    Handles `''` and `'…'` ICU escape, nested plural/select branches,
    selectordinal, and the Round-2 "=N mirrors AND CLDR categories"
    pattern. 40 tests including byte-identical round-trip on the seed.
- **M1.** Dart CLI scaffold: `dart create --template=cli` baseline, `pubspec.yaml`
  with SDK constraint `^3.4.0`, `args ^2.7.0` and `lints ^6.0.0` dev. Entry point
  at `bin/dialect.dart`. `DialectCommandRunner` wires the seven v1.0 commands
  (`init`, `import`, `describe`, `sync`, `check`, `status`, `serve`) as stubs.
  `--version` and `--help` work. Anti-goal PR checklist in
  `.github/PULL_REQUEST_TEMPLATE.md`.
- **M0+.** Multi-model convention convergence test across five models (Claude
  Opus, Claude Sonnet 4.6, Composer 2.5, Gemini 3.5 Flash, Codex 5.3). 9 of 10
  axes converged. One Round 2 patch (Arabic CLDR plural worked example).
  See `example/_validation/COMPARISON.md`.
- **M0.** Canonical convention text in `example/dialect/dialect.yaml`,
  `glossary.yaml`, and seed `source/en.arb`. Sample booking-style Flutter app
  under `example/lib/`. Validation report in
  `planning/convention-validation-report.md`.
