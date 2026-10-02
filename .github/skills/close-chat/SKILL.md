---
name: close-chat
description: "Close out a chat or work session by preserving durable context in the right memory, updating affected skills and agents when guidance changed, reviewing this skill itself, and giving a concise handoff. Use for close-chat, wrap-up, session closeout, or before ending a Vernet task."
argument-hint: "Optional focus for the closeout"
---

# Close Chat

Use this skill when the user asks to close, wrap up, or preserve the useful results of the current chat. It prepares a durable handoff and final response. It does not close the chat session through an API; no such action is available here.

## Procedure

1. Review the current conversation and worktree changes. Identify only verified, durable information that will help in future work: decisions, repository conventions, resolved pitfalls, important unfinished work, and exact validation results. Do not preserve routine chat details or unverified assumptions.
2. Inspect existing `/memories/` files before writing. Update the narrowest applicable memory rather than duplicating guidance:
   - `/memories/` for durable user-wide preferences or practices.
   - `/memories/repo/` for verified facts and conventions specific to this repository.
   - `/memories/session/` only for an unfinished task that must carry into a later chat; do not use it for completed work.
   Preserve unrelated notes. Never store secrets, credentials, personal data that is not needed, or speculative conclusions.
3. Decide whether the session revealed a durable change to repository guidance. Update only the relevant skill or agent when its instructions are incomplete, incorrect, or missing a reusable lesson. Keep instructions consistent across overlapping guidance and avoid copying whole sections.
4. Review this skill itself. If the closeout workflow exposed a reusable gap, update this skill narrowly; do not edit it merely to record the current session or create self-referential update churn.
5. Verify any edited memory or customization for scope, duplication, and internal consistency. For customization files, preserve valid frontmatter and ensure the skill name matches its directory. Do not run application tests for documentation-only closeout edits.
6. Respond with a brief closeout: what durable information was recorded, which guidance files changed (if any), the task's final state and exact verification status, and any remaining handoff item. Be explicit if there was nothing worth retaining.

## Boundaries

- Treat the user's request to close the chat as authorization to make relevant memory and guidance updates, not to commit, push, deploy, publish, or modify unrelated files.
- Never claim to have ended the chat; provide the handoff as the final response instead.
- Do not turn a one-off task outcome into a permanent preference or repository rule without evidence it will matter again.
- Leave unrelated user changes untouched.