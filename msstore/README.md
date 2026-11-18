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

`pending/` is the parking lot for languages that are written but not enabled on
the product. The tree reader only looks at directories directly under
`msstore/`, and `pending` is not a locale tag, so text there stays reviewed in
git without reaching a payload. Enable the language in Partner Center, give it
at least one screenshot, then move its directory up — renamed to the code the
Store uses. Five of these codes are bare (`cs`, `it`, `pl`, `ru`, `sk`) while
Play writes them `cs-cz`, `it-it`, `pl-pl`, `ru-ru`, `sk-sk`; the locale pattern
accepts both spellings, so what matters is matching the capture, not the Play
tree. The eight that were parked here moved up on 2026-11-18, which makes this
tree 29 locales.

`reserved_titles.txt` lists the product names Partner Center has reserved. A
`title.txt` outside that list is therefore skipped, with a log line naming the
locale and its length, and the title the Store already serves is kept; the
localized taglines stay committed until their names are reserved.

The same locale set is declared in the package itself: `msix_config: languages`
in `pubspec.yaml` is what `msix:create` writes into the AppxManifest, and that
manifest is what the Store's Languages tab reads. Keep the two in step — a
language listed here but not there is a listing the package does not claim. The
key is one comma-separated string rather than a YAML list, because msix parses
it as a string and a list fails the Windows build outright, and
`test/scripts/msix_languages_test.dart` fails if the line and this tree drift
apart.

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

Use the Add/remove languages picker, not the listing CSV, to bring a parked
locale back. The CSV import can add a language the product never had, but it
cannot fill one the product already lists as `Incomplete`: those columns stay
empty, and a locale whose canonical code carries no region (`cs`, `it`, `pl`,
`ru`, `sk`) is silently dropped when the file names it the Play way, as
`cs-cz`. Deleting the language and re-adding it through the picker is the only
route that produces a listing the Store will accept text for.

`release_notes.txt` is the one file that changes every release. The Play
changelogs under `android/fastlane/metadata/android/en-US/changelogs/` are the
source of truth for what shipped — one plain line per change, no tag format —
and the Store limit is 1500 characters, so compress to what a Windows shopper
needs rather than pasting the Android text.
