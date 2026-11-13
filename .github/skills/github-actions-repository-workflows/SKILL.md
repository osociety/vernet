---
name: github-actions-repository-workflows
description: "Diagnose GitHub Actions failures from a run URL or log, modify workflow YAML, review branch and matrix dependencies, or clean repository workflow and ignore rules."
argument-hint: "GitHub Actions run URL, workflow error, branch policy, or repository cleanup request"
---

# GitHub Actions and Repository Workflows

Use this for GitHub Actions failures, workflow changes, branch protection or branch-policy work, and repository clutter or ignore-rule reviews.

## Procedure

1. Start from the supplied run URL, failing job, workflow file, or repository-cleanup request. For a run URL, retrieve the run and job logs directly when GitHub access is available. Identify the first failing step and the earliest project-owned error; distinguish a code failure from a runner, permission, secret, or service failure. For a slow-leg question, get per-step durations from the jobs API (`gh api repos/<owner>/<repo>/actions/runs/<run>/jobs`, whose `started_at`/`completed_at` and per-job steps bound each stage) and confirm the command bodies with `gh run view --job <id> --log`; `gh api …/jobs/<id>/logs` fails on these runners with "the response contains terminal escape sequences; pass --allow-escape-sequences". Separate runner queue wait and inter-step overhead, which no YAML change can remove, from work the workflow actually controls.
2. Inspect the relevant workflow and its adjacent matrix, dependency, trigger, and artifact steps. For test pipelines, preserve the requested ordering and platform/matrix semantics; do not introduce redundant jobs or guessed flags. Every workflow needs a top-level `permissions:` block; CodeQL's `actions/missing-workflow-permissions` (surfaced as bot review comments) flags any that omit it. Test-only reusable workflows need `contents: read`, while tag, release, and discussion jobs need the specific write scopes they use. A scope that a called reusable workflow requests must already be granted by **every** caller above it, because a called workflow can only narrow permissions, never add one, and the cap is transitive through nested `uses:` chains. GitHub rejects it at parse time, before any job starts, and reports it against the *caller* — the message names the top-level workflow and points at the calling job's `uses:` line, not at the file that asked for the scope, so read "is only allowed 'actions: none'" as "one of my callers is missing this". Validate without a run: parse every workflow, walk the `uses:` edges from each root, and fail when any file's own block exceeds the per-scope minimum of its chain.
3. For repository cleanup, inspect the specific candidate files and existing `.gitignore` before proposing removals. Separate generated output from assets, source, signing configuration, and locally modified user files. Never delete files as a substitute for documenting why they are generated.
4. In this project, `main` is the only branch work lands on — the `dev` branch was deprecated 2026-11-08 — and `store` is now an Android **build flavor** inside this repository rather than a branch or the `osociety/vernet-store` fork, which still serves Google Play but takes no new work. Treat the older preference as historical intent: inspect current branches and workflow rules before changing policy, and do not remove branches or protections without explicit authorization. Merged PR head branches are deleted automatically, so a local branch whose remote is gone is not evidence of unfinished work.
5. Make the smallest workflow or ignore-rule change that addresses the evidence. Do not change application behavior to work around a CI configuration problem unless the logs show that is the root cause.
6. Validate the changed workflow syntax and run the narrowest available local equivalent. Report the exact workflow/job/step and distinguish verified fixes from checks that require GitHub Actions.

## Safety

- Check `git status` and preserve all existing edits; do not reset, checkout over, or clean user work.
- Never print, commit, or replace signing keys, tokens, or secret values. Refer to secret names only.
- Do not commit, push, delete branches, alter branch protection, or deploy unless the user explicitly asks for that action.
- If GitHub logs are unavailable, say so and request the smallest relevant log excerpt rather than guessing.
