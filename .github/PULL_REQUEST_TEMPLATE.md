<!--
Thanks for contributing to Vernet!

Keep PRs small and single-purpose. Fill in the checklist below before marking
the PR ready for review — the same checks run in CI, but running them locally
catches problems hours earlier and keeps the required CI legs green on the
first push.
-->

## Summary

<!-- What changes and why. Link an issue this closes with "Fixes #". -->

## Local verification

Run these locally on the branch head before requesting review. Re-run them
whenever `main` moves — CI checks the synthetic merge commit, not your branch
head.

- [ ] `dart format --set-exit-if-changed .` reports no changes
- [ ] `flutter analyze --no-fatal-infos --fatal-warnings` reports no new issues
- [ ] Tests covering the changed code pass, and the full `flutter test` suite passes
- [ ] A bug fix ships with a test that fails without the fix
- [ ] Changes to scan, speed-test, settings or notification behaviour were checked against the matching integration suite
- [ ] `pubspec.yaml` gained no dependency (it must stay ad-free for F-Droid), or the reason is in the Summary
- [ ] Workflow, build or platform files are unchanged, or the change intends them and says so
- [ ] Every commit is signed — unsigned commits are blocked from merging to `main`
- [ ] The diff contains no secrets, tokens or pasted terminal junk (including non-ASCII)
