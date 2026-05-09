# Reference Repos — Dialect

Repos to study for architecture decisions, implementation patterns, and competitive understanding.

## Localization Tools

| Repo | Why Study | What to Learn |
|------|-----------|---------------|
| [i18next/i18next](https://github.com/i18next/i18next) | Dominant JS i18n runtime | Plugin architecture, namespace design, interpolation API |
| [nicklockwood/SwiftFormat](https://github.com/nicklockwood/SwiftFormat) | CLI tool with config file pattern | How to design a CLI that reads project config (similar to dialect.yaml) |
| [nicklockwood/iVersion](https://github.com/nicklockwood/iVersion) | OTA update pattern for iOS | Lightweight version checking and update protocol |

## ARB/Translation Formats

| Repo | Why Study | What to Learn |
|------|-----------|---------------|
| [nicklockwood/SwiftFormat](https://github.com/nicklockwood/SwiftFormat) | AST-based file transformation | Pattern for reading → transforming → writing structured files |
| [AnyLocale](https://github.com/nicklockwood/AnyLocale) | Multi-format conversion | How to handle format adapters (ARB ↔ .strings ↔ XML) |

## CLI Design Patterns

| Repo | Why Study | What to Learn |
|------|-----------|---------------|
| [oven-sh/bun](https://github.com/oven-sh/bun) | Fast CLI UX | How to make CLI output beautiful and fast |
| [astral-sh/ruff](https://github.com/astral-sh/ruff) | Config-driven linting CLI | `ruff.toml` pattern similar to `dialect.yaml` |

## Notes

- Clone repos to `~/Documents/github/references/` for local study
- Don't clone into this brainstorm repo (keeps git history clean)
