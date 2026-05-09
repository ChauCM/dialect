# Dialect Adoption Evaluation (Duolingo Principal Engineer Lens)

## Scope

Evaluate Dialect as if it were a working product for a large multilingual organization shipping across:

- Flutter clients
- React web clients
- Backend services

Decision criteria:

- Merge conflicts at scale
- Translator workflows
- CI integration
- AI-native behavior at 50+ locales

---

## Executive Verdict

Dialect is a strong foundation, but not sufficient as the primary localization system for a 50+ locale org with high release velocity and dedicated translation operations.

Recommendation: adopt selected core ideas (canonical source format, sync adapters, correctness checks), but build or extend in-house for workflow governance, quality controls, and scale-safe operations.

---

## 1) Merge Conflicts at Scale

### What works

- Canonical source under `dialect/source` reduces cross-platform drift.
- Platform outputs are generated, reducing manual edits in downstream files.
- Split-file architecture by feature is explicitly designed to reduce conflicts.

### Gaps for 50+ locales

- Source changes still fan out across many locale files and generated artifacts.
- No documented strategy for deterministic key ordering, merge drivers, or bot-assisted conflict resolution.
- No branching/release model guidance (for example, trunk gating vs release branch localization freezes).

### Assessment

Improvement over ad hoc localization, but not conflict-resilient enough for very high parallel development volume.

---

## 2) Translator Workflows

### What works

- `dialect serve` provides a local review UI.
- Context metadata (`@key` descriptions, glossary) improves quality versus isolated string spreadsheets.
- Human lock/pin mechanism prevents AI overwrites for approved strings.

### Gaps for enterprise translation operations

- Localhost workflow is developer-machine-centric, not operations-centric.
- No native role-based permissions, reviewer assignment, approval states, comment threads, or audit trails.
- No translation memory, vendor handoff pipeline, throughput/SLA monitoring, or market sign-off workflow.

### Assessment

Great for engineer-led and small-team workflows; insufficient for mature localization organizations with dedicated linguists and compliance/legal stakeholders.

---

## 3) CI Integration

### What works

- `dialect check --strict` catches structural and semantic errors:
  - missing keys
  - placeholder mismatches
  - plural category issues
  - untranslated values
- `dialect diff` supports PR review visibility.

### Missing for large-scale release governance

- No first-class support for staged locale quality gates (tier-1 locales stricter than long-tail locales).
- No pseudo-localization validation hooks.
- No screenshot/in-context visual verification integration.
- No release-channel policy model (blocker/warning thresholds by product surface).

### Assessment

Solid baseline CI hygiene, but not full localization release governance.

---

## 4) AI-Native Approach with 50+ Locales

### What works

- AI-assisted delta translation can dramatically speed up iteration.
- In-code context and glossary constraints are directionally correct.
- Human lock/pin offers basic protection from regression.

### Risks at scale

- LLM quality variance increases across long-tail locales and domain-specific phrasing.
- No documented confidence scoring, model fallback policy, or automated linguistic QA scoring.
- No explicit cost-control framework for very large translation volume.
- No required human-review pathway for regulated, legal, or pedagogically sensitive copy.

### Assessment

Promising accelerant, but under-specified as a dependable production strategy for 50+ locales without additional governance layers.

---

## Cross-Platform Fit (Flutter + React + Backend)

Strong architectural fit:

- ARB canonical source works naturally for Flutter.
- React and React Native i18next conversion path is practical.
- Backend JSON adapters unify messaging across services.

This part is one of Dialect's strongest advantages and worth preserving.

---

## Build vs Buy Decision

## Recommendation: Hybrid (Adopt Core + Build Missing Capabilities)

Do not fully buy as-is.
Do not rebuild everything from scratch.

Instead:

1. Adopt Dialect-style canonical model and sync/check mechanics.
2. Build in-house layers for:
   - translator operations and workflow governance
   - quality scoring and human approval controls
   - branch/merge scalability and release policy enforcement
   - analytics and reliability controls for AI translation in long-tail locales

---

## Final Call

If the goal is fast developer-driven localization, Dialect is compelling.
If the goal is production-grade localization at Duolingo scale, it needs substantial in-house extension before it should become the system of record.
