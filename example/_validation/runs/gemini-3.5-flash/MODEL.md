Gemini 3.5 Flash
Cursor IDE
2026-05-21
none
final notes:
Final Report
1. What was clear in the convention
Exclusion List: The "What NOT to extract" guidelines were extremely precise. It was clear that personal names ("Linh", "Linh Nguyen"), email addresses, specific currency amounts like $82 or $246 (data), and language self-names ("English") should remain hardcoded in the codebase.
The Glossary: The semantic intent of key terms like Book (verb, not physical noun), Host (role, not server/party), and Trip (travel plan, not business trip or stumble) was perfectly defined, along with their exact translations and regional inflections.
Formality Requirements: Specifying informal/formal bounds per language (e.g., tú for Spanish, du for German, polite-neutral ます for Japanese, and bạn for Vietnamese) made formatting the tone straightforward.
No Metadata in Translations: The constraint that metadata blocks (@key) only belong in the source locale (en.arb) and must not be mirrored in translation files was unambiguous.
2. What was ambiguous and what I chose
Currency/Price Formatting: The strings in checkout_screen.dart utilize raw integers combined with hardcoded currency symbols (e.g., \$${widget.pricePerNight} per night and Total: \$$total).
The Ambiguity: If the dollar sign is separate from the numeric amount in Flutter, how should the ARB placeholders be shaped? If we use a string placeholder containing the formatted amount, it bypasses formatting logic. If we use an integer placeholder, the dollar sign must be a literal in the ARB.
My Choice: I chose to define price and total as int placeholders in @key.placeholders and kept the literal $ symbol in the ARB string itself (e.g., "${price} per night", "Total: ${total}"). This aligns perfectly with the rule: "Do not translate currency symbols... Match the position of the currency symbol used in the source string. Per-locale repositioning of $ is a runtime concern (intl), not a translation concern."
"Two screens rendering the same string" Rule: HomeScreen and CheckoutScreen both display "Hosted by {hostName}".
The Ambiguity: Since the rule states "Two screens that currently render the same English string should get separate keys", but also "Only put strings under common. when they are logically shared"*, I had to decide if "Hosted by" should be common or screen-specific.
My Choice: Since a host card in the checkout flow could logically require different styling/phrasing than a list tile subtitle on the home feed, I treated them as screen-specific: home.hostedBy and checkout.hostedBy instead of a shared common key.
Logically Shared "Delete" Action: The settings screen features a "Delete" button inside the alert dialog.
The Ambiguity: Should this button action use its own settings.deleteButton key or a shared common key?
My Choice: Since "Delete" (much like "Cancel", "Save", "Loading") is universally reusable across most mobile apps for confirmation triggers, I created a logically shared common.delete key, aligning with the rule: "Only put strings under common. when they are logically shared (Cancel/Save/Loading/Delete)."*
3. Anything that would trip up a less careful agent
Arabic Plural CLDR Categories: In Arabic, plurals demand six forms (zero, one, two, few, many, other) rather than just one and other. A less careful agent might mechanically translate English's one and other into Arabic without adding the necessary CLDR forms (two, few, many), leading to runtime crashes or broken syntax when the item count is 2, 3, or 11.
Accidental Extraction of Hardcoded Listing Data: A naive parser might extract "Seaside cottage in Da Nang" and "Linh Nguyen" into en.arb because they are user-facing. Missing the "What NOT to extract" block (which excludes demo mock listings and personal names) would bloat the translation files with garbage data.
Exact-Match Plural Constraints: The rule "If the source provides exact-match cases like =0 or =1, mirror them in translations. Don't synthesize extra exact-match cases the source doesn't have" is subtle. A less careful agent might forget to define =0 in Japanese or Vietnamese translations for checkout.itemCount (since Japanese only uses other by default), which would break compatibility with the source schema.
Inflecting Glossary Terms: A mechanical translation of "By booking you agree..." using the exact dictionary word "Đặt" (Verb) rather than "Đặt phòng" (Booking) or "Mit der Buchung..." (German noun form of Buchen) would sound incredibly robotic. An agent must understand that the glossary terms represent lemmas and must be grammatically declined/inflected to fit the target language's syntax.
4. Confidence Score: Identical Output
Confidence Rating: 85%
Reasoning:
Key Names and Structure (95%): The names of namespaces (settings.*, checkout.*, home.*) and keys are highly predictable from the UI hierarchy, and the metadata structure is explicitly defined. Almost any high-quality model would produce near-identical keys.
Source/Metadata Extraction (90%): The extraction guidelines leave little room for error once the exclusion list is parsed. Any competent agent will extract the same user-facing strings.
Translations (75%-80%): Language is rich with synonyms. While another agent must use the glossary terms (Chủ nhà, Gastgeber, Reservar, etc.) and adhere to the du / tú formality, they might choose slightly different phrasing for descriptions or surrounding words (e.g., German "Mit der Buchung..." vs "Durch das Buchen...", or Spanish "Consulta tus viajes..." vs "Revisa tus viajes..."). However, the final ARB structures and overall meanings will be functionally equivalent and fully align and satisfy all constraints.