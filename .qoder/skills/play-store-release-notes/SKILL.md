---
name: play-store-release-notes
description: "Produce Vernet Google Play release notes for every Play Console locale — the plain en-US block plus all 29 localized <locale> blocks for the bulk editor, each inside Play's 500-character limit."
---

# Play Store Release Notes

Pointer skill. The source of truth is
`.github/skills/play-store-release-notes/SKILL.md` — read it and follow
it in full.

Edit that file rather than this one so Copilot and Qoder agents stay in
sync.

The load-bearing detail is the locale list: Play's tags are not Flutter's
(`iw-IL`, `no-NO`, `es-419`), and all 29 of them are committed under
`android/fastlane/metadata/android/`, so a release publishes every language
from git. `scripts/play_store_listing.dart --check` gates that tree.
