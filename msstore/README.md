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
git without reaching a payload. A directory name has to equal the tag the
product reports, and Microsoft does not spell those consistently: the
2026-11-18 capture served `ru` bare next to `cs-cz`, `it-it`, `pl-pl` and
`sk-sk`, while `pt-br`, `es-es` and `es-419` carry a region. The locale pattern
therefore makes the region optional, and the read-only `mode=get` run — which
prints `Captured <tags>` — is the authority on the spelling, not Microsoft's
supported-languages table and not the Play tree. The eight that were parked
here moved up on 2026-11-18, which makes this tree 29 locales.

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

Staging is refused while a draft is open. On 2026-11-18 a `PendingCommit`
submission carrying `Vernet-v1.7.0+84` was open, and every `updateMetadata`
attempt failed with a bare `Error!`; the staging runs that did land had written
into a product with no draft, or waited out a package still in certification.
The answer never says whether the draft or the package inside it is the
blocker, so clear the draft in Partner Center — commit or delete it — and
restage. The run says as much when all its attempts report `PendingCommit`.

Use the Add/remove languages picker, not the listing CSV, to bring a parked
locale back. The CSV import can add a language the product never had, but it
cannot fill one the product already lists as `Incomplete`: those columns stay
empty, and the importer keys them on Microsoft's canonical code — no region for
`cs`, `it`, `pl`, `ru` and `sk` — so it drops a column named the Play way. The
listing the product then carries can spell that language differently again: this
product serves `cs-cz`, `it-it`, `pl-pl` and `sk-sk`. That is why the tree
follows what `mode=get` prints and never a CSV or a table. Deleting the language
and re-adding it through the picker is the only route that produces a listing the
Store will accept text for.

`release_notes.txt` is the one file that changes every release. The Play
changelogs under `android/fastlane/metadata/android/en-US/changelogs/` are the
source of truth for what shipped — one plain line per change, no tag format —
and the Store limit is 1500 characters, so compress to what a Windows shopper
needs rather than pasting the Android text.
