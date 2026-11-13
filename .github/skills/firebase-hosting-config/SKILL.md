---
name: firebase-hosting-config
description: "Troubleshoot Firebase Hosting, Google Cloud project permissions, Firebase app configuration, or consistency between Vernet app messaging, website, and documentation."
argument-hint: "Firebase error, project ID, hosting workflow, or configuration mismatch"
---

# Firebase Hosting and Configuration

Use this when Firebase Hosting, Google Cloud permissions, Firebase project wiring, or related app/site/documentation configuration is failing or inconsistent.

## Procedure

1. Pin down the affected surface: Flutter app, Firebase Hosting site, Google Cloud project/API, CI deployment, or user-facing copy. Start with the exact error or requested change.
2. Inspect the repository's Firebase configuration, relevant workflow, app configuration, and documentation together. Compare project IDs, hosting targets, enabled services, and deployment triggers; do not assume similarly named projects or environments are interchangeable.
3. For a permission error, identify the caller, API, and required permission from the error. Separate local credentials from CI identity and explain the minimum permission needed. Do not grant IAM roles, enable paid services, or change cloud resources without explicit authorization.
4. For text or configuration consistency, identify the source of truth and update only the requested surfaces. Preserve platform-specific guards and existing deployment behavior unless the request explicitly changes them.
5. When auditing hosted copy against the app, treat `lib/` and the release assets as the source of truth and grep them for every named feature before keeping a claim on the page. Search the whole repository before deleting a site asset: SVG sources and same-dimension `.jpg` masters reference files that the HTML does not.
6. Validate local JSON/YAML and run the narrowest available build or configuration check. Do not deploy merely to validate a change; first confirm the target project and get explicit deployment authorization.
7. Verify a deployed page from its served bytes, not its status code. A catch-all rewrite to `/index.html` answers every unmatched path with `200`, so compare `content-type` and `content-length` against the known landing page. A merged site pull request is not evidence of a deployment: hosting publishes only when `.github/workflows/firebase_hosting.yml` runs.
8. Report which configuration was inspected, the evidence for the cause, and any manual Cloud Console or CI-secret steps that remain.

## Safety

- Never expose Firebase tokens, service-account contents, signing material, or other secrets in output or committed files.
- Do not remove Firebase code or change hosting targets based only on branch names; inspect the active environment and preserve user edits.
- Treat successful local configuration validation separately from successful remote deployment.
