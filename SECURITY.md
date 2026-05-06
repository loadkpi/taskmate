# Security Model

Taskmate is designed around a simple principle: **no action without explicit user approval**.

---

## Core invariants

| Invariant | Enforcement |
|-----------|------------|
| No AI call without consent | `ConsentManager` shows what will be sent and asks `y/N` (default **N**) |
| No Jira write without confirmation | `ActionGate` shows the field diff and asks `y/N` (default **N**) |
| No secrets in content sent to AI | `SecretRedactor` scans and redacts before any AI call |
| No raw prompts in audit logs | Only SHA-256 hash of prompt is stored, never the text |
| Sensitive files excluded from AI | `.taskmateignore` rules applied at classifier level |

Non-interactive mode (`--non-interactive` / CI) always **denies** by default.

---

## What data is sent to AI

When you run `taskmate improve`, `taskmate review`, or `taskmate draft`, Taskmate sends:

- The issue body (description) from your local `.md` file
- Any extra context files listed in the skill definition
- The skill's system prompt

Before sending, the content is:
1. Classified by `DataClassifier` — `:safe`, `:sensitive`, `:secret`, `:excluded`
2. Scanned by `SecretRedactor` — tokens, keys, credentials redacted to `[REDACTED]`
3. Checked against `.taskmateignore` — excluded files are never sent

---

## What data is NOT sent to AI

- Jira API credentials (`TASKMATE_JIRA_*` environment variables)
- Files matching `.taskmateignore` patterns
- Files classified as `:secret` (contain detected secrets)
- Files classified as `:excluded` (in ignored paths)
- Any content the user denies at the consent prompt

---

## Jira write protection

Every write to Jira (create or update) goes through `ActionGate`:

1. **ActionPlan** is built: lists every field that will change, with old → new values
2. **Warnings** are surfaced: read-only fields edited locally, conflict risks
3. User is shown the plan and asked `y/N`
4. On approval, the write proceeds; on denial, nothing is changed

`push --dry-run` shows the ActionPlan without any prompt or write.

After a successful push, Taskmate re-fetches the canonical Jira version and writes it
to disk so subsequent pushes have a stable baseline.

---

## Secret detection

`SecretRedactor` detects and redacts:

| Type | Pattern |
|------|---------|
| JWT tokens | `eyXXX.eyXXX.XXX` format |
| Bearer tokens | `Bearer <token>` in headers |
| AWS access keys | `AKIA...` |
| AWS secret keys | Context-aware (`aws_secret_access_key = ...`) |
| GitHub tokens | `ghp_`, `gho_`, `ghu_`, `ghr_`, `ghs_` prefixes |
| GitLab tokens | `glpat-...` |
| Private keys | `-----BEGIN ... PRIVATE KEY-----` |
| URL credentials | `https://user:pass@host` |
| Generic secrets | `password=`, `api_key=`, `token=` + value patterns |

Redacted text is replaced with `[REDACTED]` before leaving the process.

---

## Audit trail

Every AI call and Jira write is logged to `audit/`:

```
audit/
  actions/   # Jira write records
  ai/        # AI call records
```

Each audit record is a YAML file containing:
- Timestamp
- Operation type and issue key
- Fields changed (for Jira writes)
- SHA-256 hash of prompt (for AI calls — never the raw text)
- Whether user confirmed

Audit files are append-only and named with millisecond timestamps + random suffix
to prevent collisions.

---

## .taskmateignore

Works like `.gitignore`: patterns in `.taskmateignore` mark files and directories
as `:excluded` — they are never read into AI context.

```
# Never send credentials or keys
*.key
*.pem
*.p12
secrets.yml
.env

# Keep attachments local
attachments/
private/
```

The file lives in the workspace root and is committed to your repository, so the
exclusion rules are shared across your team.

---

## Threat model

| Threat | Mitigation |
|--------|-----------|
| Accidental secret exposure to AI | SecretRedactor + DataClassifier + .taskmateignore |
| Unauthorized Jira writes | ActionGate confirmation + audit log |
| Prompt injection via issue content | Content is redacted; user reviews before consent |
| Jira credential exposure | Credentials only in ENV, never in workspace.yml or audit |
| Partial Jira write on timeout | Write connection has no retry; user warned to check Jira |
| Conflict overwrite | ConflictDetector blocks push; user must resolve first |

---

## Reporting vulnerabilities

Please report security issues privately to `loadkpi@gmail.com`.
Do not open a public GitHub issue for security vulnerabilities.
