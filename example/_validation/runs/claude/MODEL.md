Claude Sonnet 4.6
Cursor (agent mode, inline)
2026-05-21
Workspace-level CLAUDE.md was present but not read per instructions; treated as a normal Flutter i18n task with no special persona.
final notes:
Final Report
What was clear in the convention
Key naming: namespace.camelCaseKey was unambiguous. Existing namespaces (common, checkout, settings, home) were evident from both the yaml and seed ARB.
What to skip: The "What NOT to extract" list was precise. Personal names (Linh, Linh Nguyen), email addresses (linh@example.com), and currency amounts as data were all cleanly excluded.
No duplication of seed keys: The 4 seed keys were left byte-for-byte identical.
Metadata in source only: @key blocks go only in en.arb, not in translation files — stated and obvious.
Glossary: Term/translation mapping was clear: Book → Reservar/予約する/احجز/Buchen/Đặt; Host → Anfitrión/ホスト/المضيف/Gastgeber/Chủ nhà; Trip → Viaje/旅行/رحلة/Reise/Chuyến đi.
Plural categories per locale: Japanese and Vietnamese take other only; Arabic takes the full 6-form set (zero/one/two/few/many/other); German and Spanish use one/other.
What was ambiguous and what I chose
'Hosted by Linh' in main.dart (home screen list tile subtitle) vs 'Hosted by ${widget.hostName}' in checkout_screen.dart: The home screen version is hardcoded sample data with a personal name inline — I treated the "Hosted by" part as incidentally demo content since the string has no placeholder and the name Linh is flagged as personal data. I only extracted the checkout version (checkout.hostedBy) where it's a live runtime template. A less careful agent might extract both as two separate keys or conflate them into common.hostedBy. The convention's "Identical-today is a coincidence" rule nudges toward two keys, but since one is genuinely demo-static, I left main.dart's version out.

checkout.pricePerNight / checkout.total with $ prefix: The convention says "Do not translate currency symbols, units, or numeric values themselves" and "Match the position of the currency symbol used in the source string." I kept $ in the string as a literal character with {price} and {total} as the numeric placeholders. The dollar sign is literal copy in the source (hardcoded \$), not a formatter. An alternate reading would be to pass the fully-formatted price string as the placeholder and have no $ in the ARB value — I judged inline-$-with-int-placeholder to be more useful for a real Flutter app using intl.

checkout.nightsCount as a plural vs. checkout.pricePerNight as a non-plural: nights varies by integer so I made it a plural. Price and total are always single values so no plural needed.

'${widget.nights} nights' in source — widget.nights is an int. I wrote the ICU plural as {nights, plural, =1{1 night} other{{nights} nights}} to match the CLDR minimum for English (and mirror the =1 exact-match style from the seed checkout.itemCount).

Section headers rendered .toUpperCase() at runtime: I stored them in normal casing in ARB (e.g. "Account", not "ACCOUNT"). The UI handles the uppercasing. This is the correct approach but an inattentive agent might uppercase them.

'Stay Booking Demo' in MaterialApp(title:): This is a brand/product name and also used as the OS task-switcher label, not as UI copy. I excluded it.

settings.sectionPreferences key name conflict with settings.title: The settings screen has both an AppBar title "Settings" (settings.title) and a Preferences section header ("Preferences", settings.sectionPreferences). These are distinct. Separately, German renders "Einstellungen" for both — which is correct.

Arabic plural forms for checkout.itemCount: The source has =0 and =1 exact-match cases. I mirrored those in Arabic and added the CLDR zero/one/two/few/many/other categories as required. The spec says "mirror exact-match cases the source has, don't synthesize extra ones" — so I kept =0 and =1 and added the CLDR categories alongside.

Things that would trip up a less careful agent
common.loading and LoadingIndicator: The widget uses 'Loading...' as a fallback, but that key already exists in the seed. A careless agent adds it again as a new key or fails to notice the overlap.
'Cancel' appears twice in checkout_screen.dart and once in the delete dialog in settings_screen.dart: Both are covered by the single common.cancel seed key. A naive agent might add settings.cancel or checkout.cancel as separate keys, which is wrong per the convention ("Only put strings under common.* when they are logically shared (Cancel/Save/Loading/Delete)").
'Delete' in the dialog vs 'Delete account' as the list item: These are different and need separate keys (settings.deleteConfirm vs settings.deleteAccount). They look superficially similar.
The _SectionHeader widget takes a String label and calls .toUpperCase() on it — the stored string is lowercase-normal; do not ARB-encode the uppercased form.
'linh@example.com' subtitle — easy to miss that this is an email address (skip), not a field label. The word "Email" above it is extractable but the address itself is not.
Confidence in reproducibility
~65% for near-identical output across agents. The clear parts (key names, skip rules, seed key preservation, no metadata in translation files) would likely converge. The areas of divergence I'd expect:

How agents handle checkout.pricePerNight/checkout.total — inline $ vs. full price as placeholder (~40% would differ here)
Whether agents extract 'Hosted by Linh' from main.dart or leave it as demo data (~50% chance of disagreement)
Arabic plural category handling — many agents get this wrong or produce fewer categories than CLDR requires
Whether checkout.nightsCount is a plural at all vs. just "{nights} nights" with a plain placeholder
Key names for section headers: settings.sectionAccount vs settings.accountSection vs settings.account — naming convention is clear but the exact camelCase form for multi-word concepts isn't specified