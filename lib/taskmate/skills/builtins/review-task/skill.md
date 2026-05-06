---
id: review-task
version: 1
source: builtin
builtin_version: "0.1.0"
source_hash: "sha256:b831753ae660f5474300938922bba0863ba51c84370298f4ab18ba87164a2416"
kind: task_review
description: "Review issue quality"
requires_ai: true

inputs:
  - name: issue_markdown
    type: markdown
    required: true

outputs:
  - name: review_markdown
    type: markdown
  - name: readiness_score
    type: integer

security:
  external_ai: requires_consent
  jira_write: false
  send_attachments: false
  send_comments: false
  send_unrelated_issues: false
---

# Review criteria

Check whether the task is:
- understandable for another developer;
- implementable without hidden context;
- testable;
- scoped;
- safe;
- explicit about dependencies;
- clear about acceptance criteria.

# Output format

Return:
- readiness score from 0 to 100;
- blocking issues;
- non-blocking improvements;
- suggested questions for the task author;
- suggested improved acceptance criteria.
