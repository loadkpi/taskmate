---
key: DEMO-1
summary: Add user authentication to the API
issue_type: Story
status: In Progress
priority: High
labels:
  - backend
  - security
components:
  - API
assignee:
  display_name: Jane Developer
reporter:
  display_name: Product Manager
story_points: 5
due_date: "2025-06-30"
sync_state: clean
jira_source_hash: sha256:0000000000000000000000000000000000000000000000000000000000000000
last_synced_local_hash: sha256:0000000000000000000000000000000000000000000000000000000000000000
last_pulled_at: "2025-05-01T10:00:00Z"
---

## Context

We need to add JWT-based authentication to our REST API so that only
authorized users can access protected endpoints.

## Requirements

- Implement JWT token generation on login
- Validate tokens on protected routes
- Return `401 Unauthorized` for missing/invalid tokens
- Token expiry: 24 hours

## Acceptance Criteria

- [ ] `POST /api/login` returns a signed JWT on valid credentials
- [ ] Protected routes reject requests without a valid `Authorization: Bearer` header
- [ ] Expired tokens return `401` with a clear error message
- [ ] Unit tests cover token generation and validation
