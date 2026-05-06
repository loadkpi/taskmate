---
key: DEMO-2
summary: Fix pagination bug in issue list endpoint
issue_type: Bug
status: To Do
priority: Medium
labels:
  - bug
  - api
components:
  - API
assignee:
reporter:
  display_name: QA Engineer
story_points: 2
sync_state: local_changed
jira_source_hash: sha256:1111111111111111111111111111111111111111111111111111111111111111
last_synced_local_hash: sha256:1111111111111111111111111111111111111111111111111111111111111111
last_pulled_at: "2025-05-01T09:30:00Z"
---

## Bug Description

The `GET /api/issues?page=2&limit=10` endpoint returns the same results
as page 1 when the `offset` parameter is not applied correctly.

## Steps to Reproduce

1. Create 15 issues in the system
2. `GET /api/issues?page=1&limit=10` → returns issues 1–10 ✅
3. `GET /api/issues?page=2&limit=10` → returns issues 1–10 ❌ (should be 11–15)

## Expected Behavior

Page 2 should return issues 11–15.

## Root Cause (suspected)

The `offset` calculation in `IssueRepository#paginate` ignores the `page`
parameter and always uses `offset=0`.
