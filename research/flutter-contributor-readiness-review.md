# Dialect Contributor Readiness Review

Date: 2026-04-22  
Role perspective: Senior Flutter OSS maintainer (10+ pub.dev packages)

## Findings (Highest Risk First)

- **Critical - Contributor legal blocker:** `README.md` still says license is TBD, which makes serious contributors and companies avoid touching code.
- **High - Convention ambiguity for key style across platforms:** `docs/architecture.md` says ARB keys are `camelCase`, but also uses dotted namespace keys as canonical examples. This needs one strict rule or explicit transform contract.
- **High - "What exists now" vs roadmap phases is unclear:** `README.md` presents `serve` and `publish` as ready core commands, while `planning/mvp-plan.md` frames them as later milestones.
- **Medium - Platform strategy is realistic but broad:** Flutter -> React/RN -> backend is a solid order, and deferring native iOS/Android OTA is honest. Scope can still overwhelm a fresh v1 unless contribution surfaces are tightly scoped.
- **Medium - OSS onboarding scaffolding is missing:** No visible `LICENSE`, `CONTRIBUTING`, `CODE_OF_CONDUCT`, or `.github` templates.

## Open Questions / Assumptions

- Assumes the documented architecture is working as described.
- Evaluates contributor ergonomics and maintainer clarity, not runtime implementation quality.
- Assumes this repo is the public contribution entrypoint.

## Close Tab Signals

- License remains undefined.
- No contributor playbook.
- Key-style contract remains ambiguous (`camelCase` vs dotted namespaces).

## Fork Tonight Signals

- Add OSS baseline (`LICENSE`, `CONTRIBUTING`, issue/PR templates).
- Publish one "golden path" example (`Flutter` sample + `dialect sync/check` in CI).
- Define adapter invariants (round-trip tests and fixture corpus per platform).
- Mark roadmap status clearly: shipped / in progress / planned.

## Verdict

Concept is strong and documentation quality is above average for v1.  
Current state is likely to attract curiosity and stars, but not yet sustained external contributor velocity.  
One focused week of OSS hygiene and scope clarity would materially improve contributor conversion.
