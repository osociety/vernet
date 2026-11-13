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
(`iw-IL`, `no-NO`, `es-419`), and only `en-US` is committed — the other 28
languages exist solely in Play Console.
