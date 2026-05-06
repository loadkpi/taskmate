---
id: improve-task
version: 1
source: builtin
builtin_version: "0.1.0"
source_hash: "sha256:6ed28a0f04f808511271c9253d9c4e8b45f00761dbade258441ad69cbc60d964"
kind: task_improvement
description: "Improve an existing issue Markdown file"
requires_ai: true

inputs:
  - name: issue_markdown
    type: markdown
    required: true

  - name: user_instruction
    type: text
    required: false

outputs:
  - name: improved_issue_markdown
    type: markdown
  - name: change_summary
    type: markdown

security:
  external_ai: requires_consent
  jira_write: false
  send_attachments: false
  send_comments: false
  send_unrelated_issues: false
---

# Goal

Improve the issue description while preserving the original intent.

# Rules

- Do not invent business requirements.
- Mark assumptions explicitly.
- Preserve existing useful details.
- Improve structure and clarity.
- Make acceptance criteria testable.
- Add missing risks and open questions.
- Do not change issue status, assignee, due date or priority.
- Do not remove important constraints.
- Do not silently change scope.

# Optional user instruction

If the user provides custom instructions, follow them unless they conflict with safety rules.
