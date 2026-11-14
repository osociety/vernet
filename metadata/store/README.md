# Microsoft Store listing text

One directory per language, named the way the Store names it: `en-us`, `de-de`,
`fr-fr`. `scripts/ms_store_listing.dart` overlays these files onto a capture of
the live submission on every publish, so the Store's screenshots, packages and
market settings come from the Store and the words come from here.

| File | Store field | Limit |
| --- | --- | --- |
| `title.txt` | Title | 256 characters, required |
| `short_description.txt` | ShortDescription | 1000 characters, 270 shown |
| `description.txt` | Description | 10000 characters, required |
| `release_notes.txt` | ReleaseNotes | 1500 characters, one per version |
| `features.txt` | Features | 20 lines, 200 characters each |
| `keywords.txt` | Keywords | 7 lines, 40 characters each |

A line-based file becomes a list, so one feature or keyword per line. A file
that is absent leaves whatever the live submission already holds for that
field, which is how a one-off Store edit survives a publish without moving into
git first.

Check the tree before pushing, and without Store credentials:

    dart run scripts/ms_store_listing.dart --check

`ms_store_metadata.yml` publishes it: a push to this directory stages a draft,
and the release pipeline submits it. A new language has to be enabled on the
product in Partner Center first (Store listing > Add/remove languages) or the
Store rejects the submission, and the assembler refuses to send a locale the
live capture does not carry until `allow_new_locales` says otherwise. Even
then a first-time locale has no screenshots, because git does not carry
images, so add them to that language in Partner Center before expecting the
update through.

`release_notes.txt` is the one file that changes every release. The Play
changelogs under `android/fastlane/metadata/android/en-US/changelogs/` are the
source of truth for what shipped — one plain line per change, no tag format —
and the Store limit is 1500 characters, so compress to what a Windows shopper
needs rather than pasting the Android text.
