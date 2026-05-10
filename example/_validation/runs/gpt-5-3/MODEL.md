Codex 5.3
Cursor IDE agent
2026-05-21
none
final notes:
What was clear
Extraction boundaries were mostly explicit: names, emails, sample listing/demo content, currency amounts-as-data, and language self-names should not be extracted.
Key naming style was clear (namespace.camelCaseKey) and screen-scoped namespaces were straightforward.
Source ARB metadata expectations were clear (description, optional context, and placeholders when needed).
Translation rules were clear on preserving placeholders and producing one file per target locale.
What was ambiguous and what I chose
MaterialApp.title (Stay Booking Demo): I treated this as a product/app name and did not extract it.
Home card subtitle Hosted by Linh: I treated that whole home card as demo content and did not extract from that instance; I extracted the real checkout Hosted by {hostName} copy instead.
Plural strategy for Arabic: I preserved source-style exact-match plural shape for parity with source keys (rather than expanding to all Arabic CLDR category branches).
Section header casing behavior (toUpperCase()): I localized the base labels (Account, Preferences, Account actions) and left runtime casing behavior implied by UI code.
What could trip up a less careful agent
Accidentally localizing demo/sample data (listing title, hardcoded person name, email) instead of only real UI copy.
Missing metadata for newly added source keys, especially placeholder typing.
Translating glossary terms too literally without respecting sense (Book verb, Host role, Trip booking journey sense).
Forgetting that translation ARBs should contain values only (no @key metadata blocks).
Renaming or altering existing seed keys instead of preserving them exactly.
Confidence on reproducibility
Medium-high (~80%).
Another careful agent should produce very similar key coverage and file outputs. The biggest variance points are:

whether to extract Stay Booking Demo,
whether to extract anything from the demo home listing subtitle,
and how strictly to model Arabic plural branches.