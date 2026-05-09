# Naming: How We Chose "Dialect"

## The Constraint

We need a name that is:

- Short and typeable (it's a CLI command you type often)
- Unique and searchable on Google
- Available on pub.dev, npm, GitHub, and ideally as a `.dev` domain
- Evokes "translation" or "languages" without being generic
- Sounds natural as a CLI (`dialect sync`), a package (`package:dialect`), and a brand

---

## What's Already Taken

Every obvious name in the localization space is claimed:

| Name | Conflict |
|---|---|
| `l10n` | **Flutter's official `l10n.yaml` config file.** Also taken on pub.dev, and l10n.dev is a commercial product. This was our initial working name — using it would confuse every Flutter developer. |
| `tolk` | Rails i18n engine (609 GitHub stars), npm package, and TON blockchain's compiler language. |
| `arbify` | Exists on pub.dev and GitHub (abandoned but name is squatted). |
| `babel` | Famous Python i18n library + the JavaScript compiler. |
| `polyglot` / `polygot` | Multiple commercial products (polyglot.rocks, polygot.tech). |
| `linguist` | GitHub's language detection tool. |
| `rosetta` | Multiple projects across GitHub. |
| `lingo` | YC-backed lingo.dev — active, well-funded commercial product. |
| `languine` | Active commercial product (1.9K GitHub stars). |
| `tolgee` | Active pub.dev package and translation platform. |
| `fluent` | Mozilla's Project Fluent i18n system. |
| `arb_gen` | Existing pub.dev package for ARB file generation. |

---

## Why "Dialect"

**Dialect** — a regional variety of a language. Same content, different expression depending on where you are. That's exactly what localization is.

### It works everywhere

| Context | How it reads |
|---|---|
| CLI commands | `dialect init`, `dialect sync`, `dialect check`, `dialect publish` |
| Config file | `dialect.yaml` — zero collision with Flutter's `l10n.yaml` |
| Dart package | `package:dialect` |
| Flutter OTA package | `package:dialect_ota` |
| Conversation | "We use Dialect for localization" |
| Search | "dialect localization" ranks distinctively |

### It avoids the problems

- **Not generic** like `l10n` or `i18n` — you can actually Google it in context.
- **Not already a major project** in the localization or dev tools space.
- **No ambiguity** — unlike `tolk` (which means different things in Scandinavian, Rails, and blockchain), "dialect" has one clear association.
- **Clean config filename** — `dialect.yaml` doesn't conflict with anything in any framework.

### Alternative (backup)

If `dialect` is taken on pub.dev at publish time: **Arbiter** (ARB + "one who decides"). `arbiter sync`, `arbiter.yaml`. Less elegant but has the ARB connection baked in.

---

## Full Brand Map

| Surface | Name |
|---|---|
| Project name | Dialect |
| CLI tool | `dialect` |
| Config file | `dialect.yaml` |
| Glossary file | `glossary.yaml` (inside `dialect/` directory) |
| Flutter OTA package | `dialect_ota` |
| AI convention | `dialect.yaml` header comments (editor-agnostic, teaches any AI assistant the convention) |
| GitHub org | `dialectdev` or `dialect-tools` |
| npm package (if needed later) | `@dialect/cli` or `dialect-l10n` |
| Hosted service (future) | Dialect Cloud |
| Domain (check availability) | `dialect.dev` or `getdialect.dev` |

---

## On the Config Format: YAML

**Use YAML**, not JSON or TOML. Reasons:

- Flutter devs already live in YAML daily (`pubspec.yaml`, `l10n.yaml`, `analysis_options.yaml`).
- YAML supports comments — developers will want to annotate locale configs and platform settings.
- `dialect.yaml` is clean and reads naturally.
- TOML would also work technically but is less familiar to the Flutter/Dart audience.

The filename `dialect.yaml` is the key decision here — it has zero collision with any existing tool or framework config file.
