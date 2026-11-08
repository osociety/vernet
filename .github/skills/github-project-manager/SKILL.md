---
name: github-project-manager
description: "Manage the Vernet GitHub project board: add issues, set milestones, priorities, effort, types, labels, and organize issues across milestones. Use when asked to triage issues, rebalance milestones, update project metadata, or consolidate duplicates."
argument-hint: "Describe the project management task — e.g., 'move all High priority issues to Q4', 'add remaining issues to project', 'rebalance milestones'"
---

# GitHub Project Manager

Manage the osociety/vernet GitHub project board and issue metadata non-interactively via `gh` CLI and GraphQL.

## Project reference

- **Vernet project**: `https://github.com/orgs/osociety/projects/1`
- **Project node ID**: `PVT_kwDOBrhdxM4AGto0`
- **Repository**: `osociety/vernet`

### Milestones

| Number | Title | GraphQL Node ID |
|--------|-------|-----------------|
| 5 | 2026 Q4 | `MI_kwDOFk05z84BF6ej` |
| 6 | 2027 Q1 | `MI_kwDOFk05z84BF6eu` |
| 7 | 2027 Q2 | `MI_kwDOFk05z84BF6ey` |
| 8 | 2027 Q3 | `MI_kwDOFk05z84BJtom` |
| 9 | 2027 Q4 | `MI_kwDOFk05z84BJton` |

Refresh these if new milestones are added:
```bash
gh api graphql -f query='query { repository(owner:"osociety", name:"vernet") {
  milestones(first:10) { nodes { id number title } }
} }'
```

### Issue types (org-level node IDs)

| Type | Node ID |
|------|---------|
| Task | `IT_kwDOBrhdxM4BDejs` |
| Bug | `IT_kwDOBrhdxM4BDeju` |
| Feature | `IT_kwDOBrhdxM4BDejx` |

### Issue fields

| Field | Options |
|-------|---------|
| Priority | Urgent, High, Medium, Low |
| Effort | High, Medium, Low |

**Project-level field IDs** (use these for `updateProjectV2ItemFieldValue`):
| Field | Field ID | Option IDs |
|-------|----------|------------|
| Priority | `PVTSSF_lADOBrhdxM4AGto0zhpBmxo` | Urgent=`dd2d529e`, High=`54c61ba0`, Medium=`6d1347d6`, Low=`99797d4b` |
| Effort | `PVTSSF_lADOBrhdxM4AGto0zhpBmzo` | High=`032ef159`, Medium=`fd18f91c`, Low=`bbdad0bd` |
| Status | `PVTSSF_lADOBrhdxM4AGto0zgD3mrc` | Todo=`f75ad846`, In Progress=`47fc9ee4`, Done=`98236657` |

Note: Org-level issue fields (set via `updateIssue` with `issueFieldUpdates`) have ORG_ONLY visibility and don't populate project-level sorting. Always use the project-level field IDs above for project board operations.

## Common operations

### 1. Audit issue metadata completeness

Find all open issues missing milestone, type, priority, or effort:

```bash
gh api repos/osociety/vernet/issues --paginate -q '
  [.[] | select(.state == "open" and (.pull_request == null))
  | {number, title,
     has_milestone: (.milestone != null),
     has_type: (.type != null),
     has_fields: (.issue_field_values | length > 0),
     milestone: (.milestone.title // "none"),
     type: (.type.name // "none"),
     priority: ([.issue_field_values[] | select(.issue_field_name == "Priority") | .single_select_option.name] | first // "none"),
     effort: ([.issue_field_values[] | select(.issue_field_name == "Effort") | .single_select_option.name] | first // "none")
  }]
'
```

### 2. Set metadata on issues

Use GraphQL `updateIssue` to set milestone, priority, effort, and type in one mutation:

```bash
gh api graphql -f query='mutation {
  updateIssue(input: {
    id: "ISSUE_NODE_ID",
    milestoneId: "MILESTONE_NODE_ID",
    issueTypeId: "TYPE_NODE_ID",
    issueFieldUpdates: [
      {fieldName: "Priority", operation: SET, value: "Medium"},
      {fieldName: "Effort", operation: SET, value: "Low"}
    ]
  }) { issue { number } }
}'
```

For batch updates, loop over issue node IDs:

```bash
for pair in "NUM:NODE_ID" "NUM:NODE_ID" ...; do
  num="${pair%%:*}"; id="${pair##*:}"
  gh api graphql -f query="mutation { updateIssue(input: {id: \"$id\", ...}) { issue { number } } }"
done
```

### 3. Get issue node IDs

```bash
# Single issue
gh api graphql -f query='query { repository(owner:"osociety", name:"vernet") {
  issue(number:NNN) { id title }
} }' --jq '.data.repository.issue'

# Batch — all open issues
gh api graphql -f query='query { repository(owner:"osociety", name:"vernet") {
  issues(first:50, states:OPEN, orderBy:{field:CREATED_AT, direction:DESC}) {
    nodes { number id title }
  }
} }'
```

### 4. Add issues to project

```bash
gh api graphql -f query='mutation {
  addProjectV2ItemById(input: {
    projectId: "PVT_kwDOBrhdxM4AGto0",
    contentId: "ISSUE_NODE_ID"
  }) { item { id } }
}'
```

### 5. Move issues between milestones

Use the `updateIssue` mutation with `milestoneId`. Batch multiple moves in parallel `gh api graphql` calls.

### 6. Manage sub-issue hierarchy

```bash
# Link child under parent
gh api graphql -f query='mutation {
  addSubIssue(input: {
    issueId: "PARENT_NODE_ID",
    subIssueId: "CHILD_NODE_ID"
  }) { clientMutationId }
}'

# Reparent: remove from old parent first, then add to new
gh api graphql -f query='mutation {
  removeSubIssue(input: {
    issueId: "OLD_PARENT_NODE_ID",
    subIssueId: "CHILD_NODE_ID"
  }) { clientMutationId }
}'

# Check existing parent
gh api graphql -f query='query { repository(owner:"osociety", name:"vernet") {
  issue(number:NNN) { parent { number title } }
} }'

# Check sub-issue count
gh api graphql -f query='query { repository(owner:"osociety", name:"vernet") {
  issue(number:NNN) { subIssues(first:1) { totalCount } }
} }'
```

### 7. Manage labels

```bash
# Add label
gh issue edit NNN --repo osociety/vernet --add-label "label-name"

# Remove label
gh issue edit NNN --repo osociety/vernet --remove-label "label-name"

# List available labels
gh label list --repo osociety/vernet --limit 50
```

### 8. Find duplicates and similar issues

```bash
# Search by keyword
gh search issues "query" --repo osociety/vernet --limit 10

# List all open issues for manual review
gh api repos/osociety/vernet/issues --paginate -q '
  .[] | select(.state == "open" and (.pull_request == null))
  | "#\(.number) \(.title)"
'
```

### 9. Close issues

```bash
# Close as completed
gh issue close NNN --repo osociety/vernet --reason completed

# Close as not planned
gh issue close NNN --repo osociety/vernet --reason "not planned"
```

**Safety:** Never close issues unless the user explicitly requests it.

### 10. Rebalance milestones

When redistributing issues across milestones:

1. List all open issues grouped by current milestone.
2. Identify the target distribution based on priority, effort, and theme.
3. Move issues using batch `updateIssue` mutations.
4. Verify the final distribution.

Guidelines for rebalancing:
- Keep parent issues in the same milestone as their earliest sub-issue, or in the milestone where the bulk of the work lands.
- Urgent/High priority bugs always go to the earliest available milestone.
- Group related sub-issues under the same parent's milestone when possible.
- Balance workload: no single milestone should have more than ~50% of total open issues.

## Consolidation workflow

When asked to find and merge duplicate/similar issues:

1. **Audit** — list all open issues with titles, bodies, labels, and parent/child relationships.
2. **Identify clusters** — group issues by theme (e.g., "port scanning", "device info", "settings").
3. **Propose** — present the consolidation plan: which issues become parents, which become sub-issues, which get closed.
4. **Execute** — create new parent issues if needed, link sub-issues, move metadata, close empty containers.
5. **Verify** — confirm sub-issue counts and that no orphaned issues remain.

## Auth requirements

All operations require the `gh` CLI with these scopes:
- `repo` — issue read/write
- `read:org` — org-level issue types and fields
- `project` — project board read/write

If `project` scope is missing, tell the user:
```bash
gh auth refresh -h github.com -s project
```

For interactive auth (device code flow):
```bash
gh auth refresh -h github.com -s project -c
```

## Completion report

After any project management operation, report:
1. What changed (issues moved, metadata set, sub-issues linked, etc.).
2. Final milestone distribution as a table with counts.
3. Any issues that could not be updated, with the reason.
4. Total open issue count and project item count.
