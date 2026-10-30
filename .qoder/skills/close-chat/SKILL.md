---
name: close-chat
description: "Close out a chat or work session by preserving durable context in the right memory, updating affected skills and agents when guidance changed, reviewing this skill itself, and giving a concise handoff. Use for close-chat, wrap-up, session closeout, or before ending a Vernet task."
---

# Close Chat

Pointer skill. The source of truth is
`.github/skills/close-chat/SKILL.md` — read it and follow it in full.

Edit that file rather than this one so Copilot and Qoder agents stay in
sync.

Its step 2 targets Copilot's `/memories/`, `/memories/repo/` and
`/memories/session/`, which do not exist on disk here. Qoder agents must
substitute their own auto-memory directories: user-scoped memory for
durable preferences, project-scoped memory for verified repository facts,
and tasks rather than session memory for in-progress work. Skip anything
already recorded in `AGENTS.md` or a `SKILL.md`.
