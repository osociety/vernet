---
name: play-store-release-notes
description: "Produce Vernet Google Play release notes for every Play Console locale — the plain en-US block plus all 29 localized <locale> blocks for the bulk editor, each inside Play's 500-character limit."
argument-hint: "version or build number, e.g. 1.6.2 or 81"
---

# Play Store Release Notes

Use this when asked for Play Store / Play Console release notes, changelog
copy for the store, a translation of the notes, or "all 29 languages".
This is a copywriting task, not a build task — no Gradle, no Fastlane lane,
no upload. For building or publishing the bundle use `android-fastlane-release`.

## Procedure

1. Resolve the target release. `version:` in `pubspec.yaml` gives both halves
   (e.g. `1.6.2+81` → name `1.6.2`, build `81`). The Play note file is keyed by
   the **build number**: `android/fastlane/metadata/android/en-US/changelogs/<build>.txt`.
2. Read that file as the source of truth. If it does not exist, the release is
   not prepared yet — say so and stop rather than inventing notes.
3. Check the copy against the two other surfaces that must agree:
   `lib/values/changelog_data.dart` (the in-app What's New dialog, keyed by
   version name, not build) and `firebase/hosting` landing copy if it mentions
   features. Report a mismatch; only change files the user asked for.
4. Emit the plain block first — one sentence per line, no bullets, no markdown,
   no version header — matching the shape of `en-US/changelogs/<build>.txt`.
5. Then emit all 29 locale blocks in one code block for bulk paste, each
   `<tag>…</tag>` pair holding the translated lines in the same order.
6. Verify every block is under 500 characters. Translated text grows;
   German, Finnish and Hungarian overflow first. Shorten a translation rather
   than dropping a line.
7. Hand over raw markdown in a code block. Do not create localized fastlane
   directories and do not commit translations — see Constraints.

## Tone

Follow `feedback-concise-release-notes.md`: short, user-facing, jargon-free.
Describe what the user gets, not the internal change. Never write
"fixed a crash in HostScanBloc" — write "scans no longer stop early".
Keep the trailing "Bug fixes and performance improvements." line only when the
release genuinely has undifferentiated fixes; Play reviewers expect it.

## Locales

29 tags, verbatim as Play Console expects them. These are Play's codes, **not**
Flutter's — do not substitute `he` for `iw-IL` or `nb` for `no-NO`.

```
en-US  ar     cs-CZ  da-DK  de-DE  es-419 es-ES  fi-FI  fr-FR
hi-IN  hu-HU  id     it-IT  iw-IL  ja-JP  ko-KR  nl-NL  no-NO
pl-PL  pt-BR  ro     ru-RU  sk     sv-SE  th     tr-TR  uk
vi     zh-CN
```

Non-obvious entries worth a second look:

- `es-419` (Latin American Spanish) is separate from `es-ES`; both are required.
- `iw-IL` is Hebrew, `no-NO` is Norwegian, `zh-CN` is Simplified Chinese.
  Play still uses the legacy `iw` code.
- `ar`, `iw` are right-to-left; keep the line order identical so the
  diff against `en-US` stays readable.
- `id` is Indonesian with no region suffix; so are `ar`, `ro`, `sk`, `th`,
  `uk`, `vi`.
- There is no `pt-PT`, `zh-TW`, `fr-CA`, `en-GB`, `cs`, `da`, `nl` in this set.
  Adding one produces a locale Play rejects or silently ignores.

## Constraints

- `android/fastlane/metadata/android/` tracks **`en-US` only**, deliberately.
  The other 28 languages are pasted into Play Console's bulk release-notes
  editor by hand and are never committed. Do not add localized directories —
  Fastlane would not upload them, and a stray `pt-BR/changelogs/` tree implies
  a translation pipeline that does not exist.
- One block per locale, one sentence per line. Do not rewrap, indent, or add
  blank lines inside a block; the editor splits on newlines.
- Never state the app is ad-free on Android. The Play build serves ads via
  `store_overlay/`; only the `fdroid` and `dev` flavors are ad-free.
- Never claim a check ran that this skill did not run. Character counts are
  computed; translation quality is not machine-verified — say which is which.

## Output shape

```
New Support page for donations, stars and ratings.
Choose whether updates come from GitHub or from the store.
...

<en-US>
New Support page for donations, stars and ratings.
...
</en-US>
<ar>
...
</ar>
```
