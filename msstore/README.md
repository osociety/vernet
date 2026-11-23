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
| `keywords.txt` | Keywords | 7 lines, 40 characters each, 21 words across all 7 — and those 21 words are one budget shared by the whole submission |

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

`keyword_locales.txt` decides who spends the keyword budget, and the budget is
words, not listings. `KeywordsTotalCount` — the field the Store names when it
answers `The size of KeywordsTotalCount must be 21 or less` — counts the words a
submission's keywords use, over every locale, and it splits a keyword on a
hyphen as well as a space: `Wi-Fi device scanner` is four words, and a list that
reads as 20 words to a whitespace split is charged 22. That is why this product
was refused three times while its check was green. The 2026-11-18 and 2026-11-22
payloads sent keywords in all 29 locales, the widest list measuring 20 words
here and 22 there; the 2026-11-22+87 retry cleared 19 of them, sent ten at 70
keywords and 192 words, and was refused identically — which is what ruled out
prof18/pcenter-cli's reading of the message ("how many locales carry keywords at
all") and left the word reading allodia-eu/mail-calendar measured against a live
draft on 2026-08-03.

So the whole submission gets 21 words, and `en-us` alone spends them: its seven
terms count exactly 21. Every other locale publishes with `Keywords` cleared —
written as an empty list, not left alone, because a field the assembler leaves
alone keeps the keywords the captured draft already serves and the Store charges
those against the same 21. The nine locales whose committed lists sit at 22 words
because they write `Wi-Fi` twice are inert while they stay outside the list, and
a release blocker the moment the budget names them. That trade is deliberate and
it is reversible: which market deserves the words is a judgement about audience,
so it stays in a reviewed file, a cleared locale keeps its `keywords.txt` in git,
and rotating the budget is one line. `--check` refuses the tree when the
publishing locales add up to more than 21 words, names each one's spend, and
refuses an entry the tree does not carry, which is a typo spending nothing.

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
description, a comma-joined list or a keyword tree that spends more than the 21
words the submission is allowed fails the job in seconds and leaves the draft
uncommitted rather than half-publishing. The last is the one the check exists
for: the Store reports it only after the package sits in a draft, it names no
locale, and three releases were refused on it before the word count was read the
way the server counts it.

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
