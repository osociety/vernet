---
name: github-actions-repository-workflows
description: "Diagnose GitHub Actions failures from a run URL or log, modify workflow YAML, review branch and matrix dependencies, or clean repository workflow and ignore rules."
argument-hint: "GitHub Actions run URL, workflow error, branch policy, or repository cleanup request"
---

# GitHub Actions and Repository Workflows

Use this for GitHub Actions failures, workflow changes, branch protection or branch-policy work, and repository clutter or ignore-rule reviews.

## Procedure

1. Start from the supplied run URL, failing job, workflow file, or repository-cleanup request. For a run URL, retrieve the run and job logs directly when GitHub access is available. Identify the first failing step and the earliest project-owned error; distinguish a code failure from a runner, permission, secret, or service failure.
2. Inspect the relevant workflow and its adjacent matrix, dependency, trigger, and artifact steps. For test pipelines, preserve the requested ordering and platform/matrix semantics; do not introduce redundant jobs or guessed flags.
3. For repository cleanup, inspect the specific candidate files and existing `.gitignore` before proposing removals. Separate generated output from assets, source, signing configuration, and locally modified user files. Never delete files as a substitute for documenting why they are generated.
4. In this project, the user has previously preferred `main` and `store`, with store-specific advertising kept separate. Treat that as historical intent: inspect current branches and workflow rules before changing policy, and do not remove branches or protections without explicit authorization.
5. Make the smallest workflow or ignore-rule change that addresses the evidence. Do not change application behavior to work around a CI configuration problem unless the logs show that is the root cause.
6. Validate the changed workflow syntax and run the narrowest available local equivalent. Report the exact workflow/job/step and distinguish verified fixes from checks that require GitHub Actions.

## Safety

- Check `git status` and preserve all existing edits; do not reset, checkout over, or clean user work.
- Never print, commit, or replace signing keys, tokens, or secret values. Refer to secret names only.
- Do not commit, push, delete branches, alter branch protection, or deploy unless the user explicitly asks for that action.
- If GitHub logs are unavailable, say so and request the smallest relevant log excerpt rather than guessing.
