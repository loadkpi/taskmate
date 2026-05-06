---
id: create-task
version: 1
source: builtin
builtin_version: "0.1.0"
source_hash: "sha256:004586d9d9a602735da6285f309c9fcb457db8030bc80bc86e95fa70716ed9e8"
kind: task_generation
description: "Create issue from short user input"
requires_ai: true

inputs:
  - name: short_description
    type: text
    required: true

  - name: issue_type
    type: enum
    values:
      - Story
      - Bug
      - Task
      - Tech Debt
      - Investigation
    required: false

outputs:
  - name: issue_markdown
    type: markdown

security:
  external_ai: requires_consent
  jira_write: false
  send_attachments: false
  send_comments: false
  send_unrelated_issues: false
---

# Role

You are helping an engineering team lead create a clear issue.

# Instructions

Given a short task description, create a complete issue using the project template.

You must:
- identify missing information and list open questions;
- create clear acceptance criteria;
- define scope and out of scope;
- mention risks and dependencies;
- keep assumptions explicit;
- avoid inventing business requirements.

# Output

Return a single Markdown issue file containing:
1. All template sections filled in.
2. Open questions section with anything unclear.
3. Assumptions section with anything inferred.
4. Readiness score (0-100) as a comment at the top.

Note: MVP is one-shot generation. No interactive Q&A turns.
Open questions are embedded in the output for the user to review.
