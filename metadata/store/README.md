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

`pending/` holds the languages that are written but not enabled on the product.
Directory names there do not match the locale pattern, so the tree reader skips
them: the text stays reviewed in git without reaching a payload. Move a
directory back out once the language is enabled in Partner Center and carries at
least one screenshot. Note that five of them are named the Play way
(`cs-cz`, `it-it`, `pl-pl`, `ru-ru`, `sk-sk`) while the Store names those
languages `cs`, `it`, `pl`, `ru`, `sk`, so rename on the way out or the capture
and the tree never meet.

`reserved_titles.txt` lists the product names Partner Center has reserved. The
package declares only `en-us`, so every other language is listed under a
reserved name and the Store refuses a submission that renames one to anything
else. A `title.txt` outside that list is therefore skipped, with a log line
naming the locale and its length, and the title the Store already serves is
kept; the localized taglines stay committed until their names are reserved.

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
