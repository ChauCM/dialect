Composer 2.5
Cursor IDE (Composer agent)
2026-05-21
none
final notes:
Summary
29 keys in source en.arb (4 seed keys unchanged, 25 new)
5 translation files: es, ja, ar, de, vi
Seed keys preserved verbatim: checkout.bookNow, checkout.itemCount, common.cancel, common.loading
What was clear
Read order and workflow — dialect.yaml → glossary → seed ARB → Flutter lib/ was easy to follow.
Key naming — namespace.camelCaseKey, when to use common.* vs screen namespaces, and separate keys for identical English on different screens (home.hostedBy vs checkout.hostedBy).
What not to extract — names, emails, demo listing titles, currency numbers as literals, language self-names.
Metadata rules — @key only in source, descriptions with context/glossary sense, placeholder typing.
Glossary — Book (verb), Host, Trip with prescribed locale lemmas and inflection guidance.
Target locales — explicit list in dialect.yaml.
Seed ARB style — good examples for descriptions and ICU plural shape on checkout.itemCount.
What was ambiguous (and what I chose)
Ambiguity	Choice
MaterialApp title 'Stay Booking Demo'
Omitted — treated as product/brand name per “do not translate brand names.”
'Hosted by {name}' vs glossary “Host”
Kept English structure; in several locales used {glossary term}: {hostName} (e.g. Anfitrión: {hostName}, ホスト：{hostName}) instead of a literal “hosted by” calque.
Checkout price lines ($82 per night, Total: $246)
Split into {price} / {total} placeholders with pre-formatted strings; did not embed $ in ARB.
'48 hours' in free cancellation
Kept as fixed marketing copy in the string (not a placeholder).
checkout.itemCount in seed but unused in lib/
Still translated in all locales (required by workflow).
checkout.bookNow in Spanish
Used short Reservar (glossary lemma) rather than Reservar ahora.
Policy titles in legal disclaimer
Translated/descriptive in Romance/Germanic; kept loanwords in Japanese (ハウスルール).
common.delete
New shared key for the settings dialog (alongside existing common.cancel).
Tripwires for a less careful agent
Reusing keys for Hosted by, Book Now, Cancel, or Loading... across screens despite the “separate keys unless logically shared” rule.
Extracting demo data — listing title, profile name, email address.
Extracting 'English' for the language picker subtitle (explicitly excluded).
Inlining currency ($82) instead of placeholders for pricePerNight / total.
Mirroring @key blocks into translation ARBs.
Arabic / Japanese plurals — missing CLDR categories or adding extra =N cases the source does not have.
Mechanical glossary substitution — e.g. Reservar confirmado instead of noun form for “Booking confirmed.”
Modifying the four seed keys or sorting/metadata rules without dialect check --fix (I did not run the CLI; key order is approximate alphabetical).
Confidence another agent would match
~55–65% near-identical on key set and English source; lower on translations.

Keys: High agreement on major UI strings; divergence on edge cases (home.appTitle, whether Email subtitle needs a key, common.delete vs settings.delete).
English metadata: Wording of descriptions will vary; structure should be similar.
Translations: High variance on hostedBy phrasing, button length (Reservar vs Reservar ahora), Arabic plural forms, Japanese price word order (1泊 {price} vs {price}/泊), and policy-name handling.
A cold agent following the same files should produce a very similar key list but not byte-identical ARBs without CLI normalization and a fixed translation style guide.