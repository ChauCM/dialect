# Why Dialect

## The Problem

A Flutter developer adds a string to their checkout screen. Now they need it translated into 6 languages. The same string also needs to be on the iOS native app, the Android native app, and the Go backend that sends push notifications.

Here's what happens today:

1. Add the string to the app's translation JSON.
2. Context-switch to Lokalise (or Crowdin, or a spreadsheet).
3. Upload the key, add the English text, tag it for the right platforms.
4. Wait for translations — minutes if machine, hours-to-days if human.
5. Download translated files back into the project.
6. Now do it all again for the Go backend — different file format, different key convention, different project in the dashboard.
7. Hope both stay in sync as the source text evolves.

That last step never works. The mobile app says `checkout.paymentFailed`, the backend says `payment_failed`, and the English text is slightly different because two people typed it in two places. Multiply by 15 locales.

The core pain is not "translation is hard." It's that **there's no single source of truth that syncs across platforms.**

## The Insight

Developers who code with AI already have a translator sitting in their editor. When you just built a checkout screen, the AI has full context — the widget tree, the button semantics, the user flow. You can say *"extract all strings and translate to Spanish"* and it gets it right because it just wrote the code. It knows "Book" is a verb because it wrote the `onPressed: _handleBooking` callback.

But even a perfect AI translator doesn't solve the sync problem. You still need:

- **A standard** for how translation files are organized, so the AI produces consistent output every time.
- **A sync tool** that takes one canonical source and generates the right format for each platform — mobile, web, backend.
- **A validation layer** that catches missing keys, broken placeholders, and incomplete translations before they reach production.

## What Dialect Does

Dialect provides these three missing pieces.

**A spec** — One canonical source file (ARB format) with rich metadata: descriptions that disambiguate meaning, glossary terms that enforce brand consistency, and ICU MessageFormat for correct pluralization across locales.

**A CLI** — `dialect sync` reads the canonical source and generates platform-specific outputs: Flutter ARB, iOS `.strings`/`.stringsdict`, Android `strings.xml`, backend flat JSON or ICU JSON. `dialect check` validates completeness and correctness in CI.

**OTA delivery** — Optional over-the-air translation updates for mobile apps. Fix a bad translation without waiting for App Store review.

## The Moment That Matters

```
Dev:  "I just built the checkout screen. Extract all strings,
       add them to dialect/source/en.arb, translate to Spanish and Japanese."

AI:   *reads checkout_screen.dart*
      *adds 12 keys to en.arb with contextual @descriptions*
      *translates to es.arb and ja.arb*

Dev:  dialect sync && dialect check
      ✓ Flutter ARB updated
      ✓ iOS .strings + .stringsdict updated
      ✓ Android strings.xml updated
      ✓ Backend JSON updated
      ✓ All 3 locales complete, placeholders match

Dev:  git add . && git commit
```

One source. Every platform. 60 seconds.
