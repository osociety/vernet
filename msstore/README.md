# Microsoft Store listing text

One directory per language, named the way the Store names it: `en-us`, `de-de`,
`fr-fr`. `scripts/ms_store_listing.dart` overlays these files onto the draft
submission that `ms_store_release.yml` uploads the release package into, so the
Store's screenshots, packages and market settings come from the Store and the
words come from here. One submission carries both, and it is committed once.

| File | Store field | Limit |
| --- | --- | --- |
| `title.txt` | Title | 256 characters, required |
| `short_description.txt` | ShortDescription | 1000 characters, 270 shown |
| `description.txt` | Description | 10000 characters, required |
| `release_notes.txt` | ReleaseNotes | 1500 characters, one per version |
| `features.txt` | Features | 20 lines, 200 characters each |
| `keywords.txt` | Keywords | 7 lines, 40 characters each, 21 words across all 7, and at most 21 locales carrying them per submission |

`pending/` is the parking lot for languages that are written but not enabled on
the product. The tree reader only looks at directories directly under
`msstore/`, and `pending` is not a locale tag, so text there stays reviewed in
git without reaching a payload. A directory name has to equal the tag the
product reports, and Microsoft does not spell those consistently: the
2026-11-18 capture served `ru` bare next to `cs-cz`, `it-it`, `pl-pl` and
`sk-sk`, while `pt-br`, `es-es` and `es-419` carry a region. The locale pattern
therefore makes the region optional, and the capture the release job takes — its
log line reads `Draft <bundle> serves <count> locales: <tags>` — is the authority
on the spelling, not Microsoft's supported-languages table and not the Play tree.
The eight that were parked here moved up on 2026-11-18, which makes this tree
29 locales.

`reserved_titles.txt` lists the product names Partner Center has reserved. A
`title.txt` outside that list is therefore skipped, with a log line naming the
locale and its length, and the title the Store already serves is kept; the
localized taglines stay committed until their names are reserved.

`keyword_locales.txt` is the keyword budget, and it is a count of locales, not a
count of keywords. Microsoft caps how many listings carry keywords at all at 21
per submission — not 21 keywords, and not the 21 words one listing may use,
which a locale can be inside while the submission is still refused. The cap is
undocumented; prof18/pcenter-cli records it against the server's own message
(`The size of KeywordsTotalCount must be 21 or less`), and this product met it
twice: the 2026-11-18 and 2026-11-22 payloads were both refused with every
locale individually valid, the second with the widest list using 20 of its 21
words and `--check` green. Which locales spend the budget is a judgement about
audience rather than a limit, so it lives in a reviewed file: the ten named
there keep their keywords and the assembler clears `Keywords` on every other
locale. It writes the empty list rather than leaving the field alone, because a
field it leaves alone keeps the keywords the captured draft already serves, and
the Store charges those against the same 21.

A cleared locale keeps its `keywords.txt` in git, so rotating the budget is two
lines of the list and the words a locale gets back are the ones already
reviewed. `--check` refuses an entry the tree does not carry, which is a typo or
a parked locale spending nothing, and refuses the whole tree when no list is
committed and the locales still add up to more than 21.

The same locale set is declared in the package itself: `msix_config: languages`
in `pubspec.yaml` is what `msix:create` writes into the AppxManifest, and that
manifest is what the Store's Languages tab reads. Keep the two in step — a
language listed here but not there is a listing the package does not claim. The
key is one comma-separated string rather than a YAML list, because msix parses
it as a string and a list fails the Windows build outright, and
`test/scripts/msix_languages_test.dart` fails if the line and this tree drift
apart.

A line-based file becomes a list, so one feature or keyword per line. `--check`
refuses a one-line `features.txt` or `keywords.txt` that separates its entries
with commas, because that publishes as a single bullet and breaks no size limit
that could otherwise catch it — all 29 locales shipped one feature that way
until 2026-11-19. A file that is absent leaves whatever the live submission
already holds for that field, which is how a one-off Store edit survives a
publish without moving into git first.

The release publishes this tree. `ms_store_release.yml` uploads the signed bundle
into a draft with `msstore publish --noCommit`, captures that draft, overlays
these files onto it with `scripts/ms_store_listing.dart`, PUTs the result with
`msstore submission update --payload` and commits it with `msstore submission
publish`. Package and words go out as one submission because that is the only
order that works: `submission update` writes to the pending submission, and once
the release has committed the package that submission is in certification, so
listing text written after it can be accepted by the API and still never reach
the storefront.

Check the tree before pushing, and without Store credentials:

    dart run scripts/ms_store_listing.dart --check

The release runs the same check before it uses a credential, so an over-long
description, a keyword list over its word budget or a tree carrying keywords in
more than 21 locales fails the job in seconds and leaves the draft uncommitted
rather than half-publishing. The third is the one the check exists for: the
Store only reports it after the package is already in a draft, and it names no
locale.

A new language has to be enabled on the product in Partner Center first (Store
listing > Add/remove languages), or the assembler refuses to send a locale the
capture does not carry — `--allow-new-locales` overrides that once it has been.
Even then a first-time locale has no screenshots, because git does not carry
images, so add them to that language in Partner Center before expecting the
update through.

A bare `💥 Error!` is the CLI throwing the Store's answer away, not the answer.
The PUT for a packaged submission asks for a submission object, so an error body
that does not deserialise as the CLI's wrapped error type falls through to a
generic catch that prints those two words and no reason
(`SubmissionClient.InvokeAsync` and `StatusContextExtensions.ErrorStatus`). Only
`--verbose` carries the Store's own words, which is why the release runs its one
`submission update` with it and prints the redacted reply rather than the
command's stdout — a submission JSON holds signed upload urls and these logs are
public. Read the reason before blaming the draft: an open draft is not a write
blocker, and `publish` deletes one it finds and creates its own.

Use the Add/remove languages picker, not the listing CSV, to bring a parked
locale back. The CSV import can add a language the product never had, but it
cannot fill one the product already lists as `Incomplete`: those columns stay
empty, and the importer keys them on Microsoft's canonical code — no region for
`cs`, `it`, `pl`, `ru` and `sk` — so it drops a column named the Play way. The
listing the product then carries can spell that language differently again: this
product serves `cs-cz`, `it-it`, `pl-pl` and `sk-sk`. That is why the tree
follows what the release capture prints and never a CSV or a table. Deleting the language
and re-adding it through the picker is the only route that produces a listing the
Store will accept text for.

`release_notes.txt` is the one file that changes every release. The Play
changelogs under `android/fastlane/metadata/android/en-US/changelogs/` are the
source of truth for what shipped — one plain line per change, no tag format —
and the Store limit is 1500 characters, so compress to what a Windows shopper
needs rather than pasting the Android text.
