# Backend Platforms

How Dialect integrates with backend frameworks. Backends consume translations either at build time (locale files bundled with the service) or at app startup (fetched from a `dialect publish` bundle URL — see below).

---

## The Principle: Backend Humility

Dialect's cross-platform sync only works if backend teams agree to adopt it. FE teams dictating BE stack changes is a hard conversation — and rightly so. So Dialect is opinionated about minimizing what we ask of the backend engineer.

**Dialect outputs one format family for backends: JSON.** Either `flat-json` (no plurals) or `icu-json` (full ICU MessageFormat). That's the entire adapter surface.

**Per-stack support is a docs artifact, not an adapter.** For each backend stack, Dialect provides a thin, lossless "glue" — usually a ~30-line localizer template — that plugs Dialect's JSON output into the stack's *native* localization interface. The BE engineer's callsites don't change. Only the backing store swaps.

**What this means in practice:**

- ASP.NET teams keep `IStringLocalizer<T>`. We give them a `JsonStringLocalizer` implementation.
- Django teams keep the `_()` interface. We swap the catalog backend.
- FastAPI / Flask / Node / Go teams already use JSON-friendly libraries. Pointing them at Dialect's output is a 1-line config change.

**What this explicitly avoids:**

- A `.resx` adapter. `.resx` has no native ICU plurals and uses positional `{0}` placeholders. ARB → `.resx` is lossy in ways that matter. Lossless `JsonStringLocalizer` is the better answer.
- A gettext `.po` adapter. Django and Babel both support JSON catalogs. We document the swap instead.
- Any future adapter that would force us to silently degrade ARB features to fit a legacy format.

See [Backend Humility](../planning/competitive-strategy.md#backend-humility) for the strategic framing.

---

## Choosing a Backend Format: `flat-json` vs `icu-json`

Dialect offers two JSON-based formats for backends. The choice depends on whether your backend strings need pluralization, gender, or select expressions.

| Format | Plurals/Gender/Select | Backend Dependency | Best For |
|---|---|---|---|
| `flat-json` | Stripped — simple `{placeholder}` interpolation only | None | Simple strings: error messages, labels, notification titles |
| `icu-json` | Preserved — full ICU MessageFormat expressions | ICU parsing library | Complex strings: plurals, gender, locale-aware formatting |

**`flat-json` example:**

```json
{
  "checkoutBookNow": "Book Now",
  "checkoutItemCount": "{count} items",
  "error.paymentFailed": "Payment failed. Please try again."
}
```

**`icu-json` example (same source strings):**

```json
{
  "checkoutBookNow": "Book Now",
  "checkoutItemCount": "{count, plural, =1{1 item} other{{count} items}}",
  "error.paymentFailed": "Payment failed. Please try again."
}
```

The difference: `flat-json` converts `{count, plural, =1{1 item} other{{count} items}}` to `{count} items` (loses the plural logic). `icu-json` keeps it intact.

**When to use `icu-json`:** Your backend sends user-facing text with plurals (e.g., "You have 3 new messages"), renders emails with gender-aware greetings, or needs locale-correct plural forms (Arabic has 6 plural categories). Parse the ICU strings at runtime with `intl-messageformat` (Node), `PyICU` / `babel.support.Translations` (Python), or `MessageFormat` (C#).

**When to use `flat-json`:** Your backend strings are simple key-value pairs — error codes, notification titles, labels — with no plural or gender logic.

You can mix both in the same project for different services:

```yaml
platforms:
  api-gateway:
    output: gateway/locales/
    format: flat-json
    namespaces: [common, backend]

  notification-service:
    output: notifications/locales/
    format: icu-json
    namespaces: [common, backend]
```

---

## How Backends Use Translations

Backend services typically need translated strings for:

- API responses (error messages, validation messages, notification text)
- Email templates and push notification content
- Server-rendered HTML (if applicable)
- PDF/report generation in the user's locale

The common pattern: load a JSON file keyed by locale, look up strings at request time based on `Accept-Language` header or user preference.

---

## Live updates: `dialect pull` + redeploy (no background poller)

When translations change (translator approves an edit in `dialect serve` or in Cloud), how do backends pick up the new strings?

**Dialect's answer is deliberately simple: read locale files at app startup, run `dialect pull` in your deploy script.** No background poller in the backend library, no SDK that hits a manifest URL every 60 seconds. The operational cost of a poller (network failures, partial reads, auth header rotation, cache coherence across replicas) outweighs the benefit for almost every team.

The two supported patterns:

### Pattern 1: Bundle locale files at build time

Locale files live in your repo at e.g. `wwwroot/locales/` (ASP.NET) or `api/locales/` (Node/Go/Python). CI does:

```bash
dialect pull                 # Fetch the latest bundle into dialect/translations/
dialect sync                 # Regenerate per-platform locale files
# now build + deploy as normal
```

The deployed service reads locale files at startup. Translation updates require a redeploy — which, for most backends, happens in minutes.

### Pattern 2: Fetch a bundle URL at app startup (v1.2)

For teams that want translations to update without rebuilding (e.g. continuously-deployed services that boot frequently), the v1.2 bundle format lets the backend fetch directly:

```csharp
// ASP.NET — v1.2
builder.Services.AddDialectLocalization(opts =>
{
    opts.BundleUrl = "https://cdn.example.com/locales/prod/manifest.json";
    opts.Fallback  = "wwwroot/locales";   // bundled at build time
});
```

On startup, the service fetches the manifest, downloads any changed locale JSONs, loads them into the in-memory localizer. If the URL is unreachable, the bundled fallback wins. No background poller — the next pod restart picks up the next bundle version.

### Sub-minute updates (rare): wire your own webhook

For the small fraction of teams that genuinely need translations to land in production within seconds:

1. Expose an admin endpoint in your backend: `POST /admin/reload-translations` (require an auth header).
2. Configure a webhook from `dialect publish` (or from your Cloud project) to hit that endpoint on each publish event.
3. The endpoint re-reads the bundle URL and atomically swaps the localizer.

Dialect doesn't ship a library for this; it's ~20 lines of code per backend. Document the pattern, don't generalize it.

---

## ASP.NET (C#)

ASP.NET's standard localization story is `IStringLocalizer<T>` backed by `.resx` files. Dialect does **not** ship a `.resx` adapter. The recommended path is a **~30-line `JsonStringLocalizer`** that implements the same `IStringLocalizer<T>` interface over Dialect's `icu-json` output. **Callsites don't change** — only the registration in `Program.cs` swaps, and there's no dependency to add or version to track.

> **A `Dialect.AspNetCore` NuGet package is a planned nice-to-have, not a release requirement.** It would wrap exactly the snippet below behind `dotnet add package Dialect.AspNetCore` + `AddDialectLocalization(...)` for teams that prefer an install over a paste. Because the snippet is already complete and lossless, the package is pure ergonomics — it ships if and when there's demand, and nothing depends on it. See [`roadmap.md`](roadmap.md).

### Format

```
dialect/source/en.arb → wwwroot/locales/en.json   (icu-json)
                       → wwwroot/locales/es.json
```

### Recommended: `JsonStringLocalizer` template (~30 lines, ships today)

Drop this into your project — no dependency, lossless, preserves `IStringLocalizer<T>` callsites.

```csharp
using System.Globalization;
using Microsoft.Extensions.Localization;
using System.Text.Json;

public sealed class JsonStringLocalizer : IStringLocalizer
{
    private readonly Dictionary<string, string> _strings;

    public JsonStringLocalizer(string localesDir)
    {
        var culture = CultureInfo.CurrentUICulture.Name;
        var path = Path.Combine(localesDir, $"{culture}.json");
        if (!File.Exists(path))
            path = Path.Combine(localesDir, "en.json");

        var json = File.ReadAllText(path);
        _strings = JsonSerializer.Deserialize<Dictionary<string, string>>(json)
                   ?? new Dictionary<string, string>();
    }

    public LocalizedString this[string name] =>
        new(name, _strings.TryGetValue(name, out var v) ? v : name,
            resourceNotFound: !_strings.ContainsKey(name));

    public LocalizedString this[string name, params object[] args]
    {
        get
        {
            var template = this[name];
            // For ICU strings, plug in MessageFormat here. For flat strings, string.Format works.
            return new LocalizedString(name, string.Format(template.Value, args),
                resourceNotFound: template.ResourceNotFound);
        }
    }

    public IEnumerable<LocalizedString> GetAllStrings(bool includeParentCultures) =>
        _strings.Select(kvp => new LocalizedString(kvp.Key, kvp.Value));
}

public sealed class JsonStringLocalizerFactory : IStringLocalizerFactory
{
    private readonly string _localesDir;
    public JsonStringLocalizerFactory(string localesDir) => _localesDir = localesDir;
    public IStringLocalizer Create(Type resourceSource) => new JsonStringLocalizer(_localesDir);
    public IStringLocalizer Create(string baseName, string location) => new JsonStringLocalizer(_localesDir);
}
```

### Registration

```csharp
// Program.cs
builder.Services.AddSingleton<IStringLocalizerFactory>(
    new JsonStringLocalizerFactory(Path.Combine(builder.Environment.WebRootPath, "locales")));
builder.Services.AddSingleton(typeof(IStringLocalizer<>), typeof(StringLocalizer<>));
```

### Callsites — unchanged

```csharp
public class CheckoutController : Controller
{
    private readonly IStringLocalizer<SharedResource> _localizer;

    public CheckoutController(IStringLocalizer<SharedResource> localizer)
        => _localizer = localizer;

    public IActionResult Checkout()
    {
        ViewData["BookNow"] = _localizer["checkoutBookNow"];
        return View();
    }
}
```

### Plurals (icu-json)

For full ICU support (e.g. Arabic plurals), wrap the lookup in a `MessageFormat` parser such as [Jeffijoe/messageformat.net](https://github.com/jeffijoe/messageformat.net) or `Microsoft.Recognizers.Text`. Implementation is a one-method extension on top of the template above.

### Config

```yaml
platforms:
  aspnet:
    output: wwwroot/locales/
    format: icu-json     # use flat-json if no plural needs
    namespaces: [common, backend]
```

### Why not `.resx`?

A `.resx` adapter would require:
- Inventing a positional placeholder mapping for ARB's named `{userName}` → `.resx`'s `{0}`. Lossy.
- Dropping or refusing-to-sync ICU plural keys. Lossy.
- Maintaining XML escaping rules and a separate validation path.

The `JsonStringLocalizer` approach is lossless, ~30 lines, and preserves `IStringLocalizer<T>` callsites. There's no upside to the lossy path.

---

## Django (Python)

Django's standard localization is `gettext` `.po` files. Dialect does **not** ship a `.po` adapter — instead, we document the swap to a JSON-based catalog. The `_()` / `gettext()` callsites stay intact.

### Format

```
dialect/source/en.arb → locale/en.json   (icu-json)
                       → locale/es.json
```

### Drop-in JSON catalog

```python
# myapp/i18n.py
import json
from pathlib import Path
from django.utils.translation import get_language

_CATALOGS: dict[str, dict[str, str]] = {}

def _load(locale: str) -> dict[str, str]:
    if locale not in _CATALOGS:
        path = Path(__file__).parent.parent / "locale" / f"{locale}.json"
        with path.open() as f:
            _CATALOGS[locale] = json.load(f)
    return _CATALOGS[locale]

def t(key: str, **kwargs) -> str:
    catalog = _load(get_language() or "en")
    template = catalog.get(key, key)
    return template.format(**kwargs)  # for icu-json, swap to ICU parser
```

### Callsites

```python
from myapp.i18n import t

def checkout_view(request):
    return render(request, "checkout.html", {
        "book_now": t("checkoutBookNow"),
        "items": t("checkoutItemCount", count=3),
    })
```

### Plurals (icu-json)

Use [`PyICU`](https://pypi.org/project/PyICU/) or [`babel.support.Translations`](https://babel.pocoo.org/) to evaluate ICU MessageFormat strings at runtime. ~10 lines on top of the loader above.

### Config

```yaml
platforms:
  django:
    output: locale/
    format: icu-json
    namespaces: [common, backend]
```

### Why not `.po`?

Django's `_()` only requires a callable that returns a string. Swapping in a JSON-backed `t()` is cheaper than maintaining a `.po` adapter, and JSON preserves ICU plurals without `ngettext`'s 2-form / 6-form awkwardness.

---

## FastAPI / Flask (Python)

No platform default — modern Python web stacks are already JSON-friendly. Point your existing i18n library at Dialect's output.

### Format

```
dialect/source/en.arb → locales/en.json   (icu-json or flat-json)
```

### Drop-in loader (Flask)

```python
from flask import Flask, request
from flask_babel import Babel
import json
from pathlib import Path

app = Flask(__name__)
babel = Babel(app)

@babel.localeselector
def get_locale():
    return request.accept_languages.best_match(["en", "es", "ja"])

_CATALOGS = {
    p.stem: json.loads(p.read_text())
    for p in (Path(__file__).parent / "locales").glob("*.json")
}

def t(key: str, **kwargs) -> str:
    locale = get_locale() or "en"
    return _CATALOGS[locale].get(key, key).format(**kwargs)
```

### Drop-in loader (FastAPI)

```python
from fastapi import FastAPI, Request
import json
from pathlib import Path

app = FastAPI()

_CATALOGS = {
    p.stem: json.loads(p.read_text())
    for p in (Path(__file__).parent / "locales").glob("*.json")
}

def t(key: str, locale: str = "en", **kwargs) -> str:
    return _CATALOGS.get(locale, _CATALOGS["en"]).get(key, key).format(**kwargs)

@app.get("/checkout")
async def checkout(request: Request):
    locale = request.headers.get("Accept-Language", "en")[:2]
    return {"label": t("checkoutBookNow", locale=locale)}
```

### Config

```yaml
platforms:
  api:
    output: locales/
    format: icu-json     # or flat-json for simple strings
    namespaces: [common, backend]
```

---

## Node.js / Express

No platform default. Use `i18next-fs-backend` (or any JSON loader) to consume Dialect's output.

### Format

```
dialect/source/en.arb → api/locales/en.json   (icu-json or flat-json)
```

### Drop-in (i18next)

```js
import i18next from 'i18next';
import Backend from 'i18next-fs-backend';

await i18next.use(Backend).init({
  fallbackLng: 'en',
  backend: { loadPath: './api/locales/{{lng}}.json' },
});

i18next.t('checkoutBookNow');
i18next.t('checkoutItemCount', { count: 3 });
```

### Drop-in (vanilla, flat-json)

```js
const translations = require(`./locales/${locale}.json`);

function t(key, params = {}) {
  let str = translations[key] || key;
  for (const [k, v] of Object.entries(params)) {
    str = str.replace(`{${k}}`, v);
  }
  return str;
}
```

### Plurals (icu-json)

```js
import { IntlMessageFormat } from 'intl-messageformat';

function t(key, params = {}) {
  const msg = new IntlMessageFormat(translations[key] || key, locale);
  return msg.format(params);
}

t('checkoutItemCount', { count: 3 });
// English: "3 items"  |  Arabic: "٣ عناصر" (correct plural form)
```

### Config

```yaml
platforms:
  node:
    output: api/locales/
    format: icu-json     # or flat-json
    namespaces: [common, backend]
```

---

## Go

No platform default. `go-i18n` is the dominant library and consumes JSON natively.

### Format

```
dialect/source/en.arb → locales/en.json   (icu-json)
```

### Drop-in (`go-i18n`)

```go
import (
    "github.com/nicksnyder/go-i18n/v2/i18n"
    "golang.org/x/text/language"
    "encoding/json"
)

bundle := i18n.NewBundle(language.English)
bundle.RegisterUnmarshalFunc("json", json.Unmarshal)
bundle.LoadMessageFile("locales/en.json")
bundle.LoadMessageFile("locales/es.json")

localizer := i18n.NewLocalizer(bundle, "es")
msg, _ := localizer.Localize(&i18n.LocalizeConfig{MessageID: "checkoutBookNow"})
```

### Config

```yaml
platforms:
  go:
    output: locales/
    format: icu-json
    namespaces: [common, backend]
```

---

## Backend Platform Summary

| Stack | Output format | Integration | Effort |
|---|---|---|---|
| ASP.NET (C#) | `icu-json` | `JsonStringLocalizer` snippet over `IStringLocalizer<T>` (NuGet is a planned nice-to-have) | ~30 lines of snippet |
| Django (Python) | `icu-json` | JSON catalog loader, callsites unchanged | ~15 lines of snippet |
| Flask / FastAPI (Python) | `icu-json` or `flat-json` | Dict loader or Flask-Babel adapter | ~15 lines of snippet |
| Node.js | `icu-json` or `flat-json` | `i18next-fs-backend` config or vanilla loader | ~10 lines of snippet |
| Go | `icu-json` | `go-i18n` bundle loader (native JSON) | ~10 lines of snippet |

Every stack consumes the same versioned `icu-json` contract via a small snippet — most already have generic JSON-loading libraries (`i18next-fs-backend`, `go-i18n`) that read Dialect's output natively. A polished `Dialect.AspNetCore` NuGet (and similar per-stack packages) is a nice-to-have that can ship later if demand justifies it; none are release-blocking, and the snippets are complete and lossless on their own.

The maintenance cost stays low across the board because everything targets the same versioned `icu-json` contract — no per-stack format adapters in the CLI codebase.

---

## Shared Strings Between Frontend and Backend

A common pattern: the backend sends error messages or notification text that appears in the frontend UI. These strings should exist in the canonical source once, not duplicated.

Use the `backend` namespace for strings that only the server needs, and `common` for strings shared across both:

```yaml
platforms:
  flutter:
    namespaces: [common, mobile]
  ios:
    namespaces: [common, mobile]
  android:
    namespaces: [common, mobile]
  aspnet:
    namespaces: [common, backend]
```

`dialect sync` ensures each platform only gets the strings it needs, from the same source.
