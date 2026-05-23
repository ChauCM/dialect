/// Hand-written facade in front of the generated `embedded_assets.g.dart`.
///
/// The generator (run by `tool/build_dashboard.dart`) walks
/// `dashboard/dist/` after `pnpm build` and emits a single Dart constant
/// — a map from `index.html`-relative path to file bytes — into
/// `embedded_assets.g.dart`. That file is intentionally committed so
/// `dart compile exe` works on a fresh checkout without `pnpm` being
/// installed.
///
/// This wrapper keeps the rest of the codebase (`server.dart`, tests)
/// independent of the generator: it imports `embeddedAssets` from the
/// generated file when present and falls back to an empty map otherwise.
library;

import 'embedded_assets.g.dart' as gen;

/// Path → file bytes for every asset in the SPA build. The keys are
/// forward-slash paths relative to `dashboard/dist/` (e.g.
/// `index.html`, `assets/index-abc123.js`).
Map<String, List<int>> get embeddedAssets => gen.embeddedAssets;

/// Whether the binary has a real SPA bundle baked in. False when the
/// generator hasn't run yet (e.g. a fresh clone before
/// `dart run tool/build_dashboard.dart`) — `dialect serve` surfaces a
/// helpful hint in that case instead of returning 404 for `/`.
bool get hasEmbeddedDashboard => embeddedAssets.isNotEmpty;
