---
name: github-issue-creator
description: "Create GitHub issues with full metadata (type, labels, priority, effort, milestone), sub-issue hierarchy, and project assignment. Use when asked to create issues, file bugs, plan features, or organize work into parent/child issue trees."
argument-hint: "Describe the issue(s) to create, or paste a list of features/bugs with optional metadata"
---

# GitHub Issue Creator

Create one or more GitHub issues with complete metadata, sub-issue hierarchy, and project-board assignment — all non-interactively via `gh` CLI and GraphQL.

## Intake

1. Accept a plain-language description, a list of issues, or a structured brief (title + body + metadata).
2. Default repository is `osociety/vernet` unless the user specifies otherwise.
3. If the request is ambiguous about metadata, infer reasonable defaults from the content:
   - Bugs → type `Bug`, labels `bug`, priority `High` or `Medium`
   - Features → type `Feature`, labels `enhancement, feature request`, priority `Medium`
   - Tasks/chore → type `Task`, labels `enhancement`, priority `Low` or `Medium`
4. Confirm the plan with the user before creating if there are more than 5 issues or the metadata choices are non-obvious.

## Metadata reference

Before creating issues, resolve the available values for this repository:

```bash
# Labels
gh label list --limit 50

# Milestones (number = API ID)
gh api repos/{owner}/{repo}/milestones --jq '.[] | "\(.number): \(.title)"'

# Issue types
gh api graphql -f query='query { repository(owner:"OWNER", name:"REPO") { issueTypes(first:10) { nodes { id name } } } }'

# Issue fields (Priority, Effort, etc.)
# Use the MCP tool list_issue_fields or inspect existing issues for field names and option values.

# Project ID
gh project list --owner {org} --format json --jq '.projects[] | "\(.number): \(.id) — \(.title)"'

# Milestone GraphQL node IDs
gh api graphql -f query='query { repository(owner:"OWNER", name:"REPO") { milestones(first:10) { nodes { id number title } } } }'
```

## Issue creation procedure

### Step 1 — Create parent issues

Use `gh issue create` for each parent. This avoids OAuth restrictions that block the MCP `issue_write` tool for creation.

```bash
gh issue create --repo {owner}/{repo} \
  --title "Issue title" \
  --body '## Summary\n\n...\n\n## Sub-issues\n\n- [ ] Sub 1\n- [ ] Sub 2\n\n## Notes\n\n...' \
  --label "label1,label2" \
  --type "Feature"
```

Capture the returned issue URL to extract the issue number.

### Step 2 — Create sub-issues

Create each sub-issue the same way. Include `Parent: #NNN` in the body for traceability.

### Step 3 — Link sub-issues to parents

Get node IDs, then use the GraphQL `addSubIssue` mutation:

```bash
# Get node IDs for recent issues
gh api graphql -f query='query { repository(owner:"OWNER", name:"REPO") {
  issues(first:N, orderBy:{field:CREATED_AT, direction:DESC}) {
    nodes { number id title }
  }
} }'

# Link sub-issue to parent
gh api graphql -f query='mutation {
  addSubIssue(input: {
    issueId: "PARENT_NODE_ID",
    subIssueId: "CHILD_NODE_ID"
  }) { clientMutationId }
}'
```

**Important:** The GraphQL field for the parent is `issueId`, not `parentIssueId`.

### Step 4 — Set metadata (Priority, Effort, Milestone, Type)

Use the GraphQL `updateIssue` mutation. This works non-interactively and bypasses the MCP OAuth restriction.

```bash
# Set Priority + Effort + Milestone on a parent
gh api graphql -f query='mutation {
  updateIssue(input: {
    id: "NODE_ID",
    milestoneId: "MILESTONE_NODE_ID",
    issueFieldUpdates: [
      {fieldName: "Priority", operation: SET, value: "Medium"},
      {fieldName: "Effort", operation: SET, value: "Low"}
    ]
  }) { issue { number } }
}'

# Set Type on a sub-issue
gh api graphql -f query='mutation {
  updateIssue(input: {
    id: "NODE_ID",
    issueTypeId: "TASK_TYPE_NODE_ID"
  }) { issue { number } }
}'
```

**Issue type node IDs** (osociety org-level):
- Task: `IT_kwDOBrhdxM4BDejs`
- Bug: `IT_kwDOBrhdxM4BDeju`
- Feature: `IT_kwDOBrhdxM4BDejx`

### Step 5 — Add to project

```bash
PROJECT_ID="PVT_kwDOBrhdxM4AGto0"  # Vernet project
gh api graphql -f query='mutation {
  addProjectV2ItemById(input: {
    projectId: "PROJECT_ID",
    contentId: "ISSUE_NODE_ID"
  }) { item { id } }
}'
```

Requires the `project` scope on the `gh` CLI token. If missing, tell the user to run:
```bash
gh auth refresh -h github.com -s project
```

## Consolidation checks

Before creating new issues, check for existing similar or duplicate issues:

```bash
# Search for similar issues
gh search issues "query" --repo {owner}/{repo} --limit 10

# Or list all open issues and scan titles
gh api repos/{owner}/{repo}/issues --paginate -q '.[] | select(.state == "open" and .pull_request == null) | "#\(.number) \(.title)"'
```

If a similar issue exists, offer to add the new work as a sub-issue of the existing one instead of creating a duplicate parent.

## Batch efficiency

- Parallelize independent GraphQL mutations (multiple `gh api graphql` calls in the same block).
- Use `for` loops for repetitive operations (linking N sub-issues, setting metadata on N issues).
- Get all node IDs in one query before starting mutations.
- Group operations by type: all creates first, then all links, then all metadata updates, then all project additions.

## Completion report

After creating all issues, report:
1. Parent issue numbers and URLs with their metadata (type, priority, effort, milestone).
2. Sub-issue hierarchy as a table.
3. Any issues that could not be created or linked, with the reason.
4. Project assignment status.

## Safety boundaries

- Never create issues without the user's explicit request or approval.
- Never modify or close existing issues unless explicitly asked.
- Never expose credentials or tokens in issue bodies.
- Default to `osociety/vernet` but confirm if the user mentions a different repo.
- If `gh` CLI is unavailable or auth fails, state the exact error and what scope or tool is needed.
