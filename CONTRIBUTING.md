# Contributing to Dialect

Thanks for your interest in contributing. This guide covers how to get involved.

## Ways to Contribute

- **Report bugs** — Open an issue with steps to reproduce.
- **Suggest features** — Open an issue describing the use case, not just the solution.
- **Submit a PR** — Fix a bug, add an adapter, improve docs.
- **Write an adapter** — Platform adapters are the easiest way to make a high-impact contribution.

## Getting Started

```bash
# Clone the repo
git clone https://github.com/user/dialect.git
cd dialect

# Install Dart SDK (if not already installed)
# https://dart.dev/get-dart

# Run the CLI locally
dart run bin/dialect.dart
```

## Writing a Platform Adapter

Adapters convert canonical ARB files to platform-specific formats. Each adapter:

1. Reads a parsed ARB map (key-value pairs with metadata).
2. Transforms keys, pluralization syntax, and structure to the target format.
3. Writes the output file.

Look at the existing `flutter` (passthrough) and `i18next-json` adapters as reference.

### Adapter checklist

- Handles simple strings, placeholders, and ICU plurals.
- Outputs deterministically sorted keys.
- Includes round-trip test fixtures (source ARB → expected output → back to ARB if applicable).
- Documents format-specific limitations (e.g., flat-json loses plural forms).

## Pull Request Process

1. Fork the repo and create a branch from `main`.
2. Make your changes with clear commit messages.
3. Run `dialect check` on the test fixtures to verify correctness.
4. Open a PR with a description of what changed and why.

## Code Style

- Dart code follows `dart format` defaults.
- Keep functions small and testable.
- Prefer explicit types over `var` for public APIs.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
