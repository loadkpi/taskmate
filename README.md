# Taskmate

**Secure-by-default, local-first AI assistant for managing Jira tasks through a Git-friendly Markdown/YAML workspace.**

> AI suggests. User reviews. User approves. Taskmate applies.

Taskmate turns Jira into a local workspace: issues are stored as plain Markdown files you can read, edit in any IDE, commit to Git, and sync back to Jira with explicit confirmation.

Works great without AI — as a CLI for local Jira management. AI is an optional layer on top.

---

## Installation

```bash
gem install taskmate
```

Or add to your Gemfile:

```ruby
gem "taskmate"
```

Requires Ruby >= 3.3.

---

## Quick start

```bash
# 1. Initialize a workspace in your project directory
taskmate init

# 2. Set your Jira credentials
export TASKMATE_JIRA_URL=https://your-org.atlassian.net
export TASKMATE_JIRA_EMAIL=you@example.com
export TASKMATE_JIRA_TOKEN=your-api-token

# 3. Check everything is configured correctly
taskmate doctor

# 4. Pull an issue from Jira
taskmate pull SAR-123

# 5. Edit the issue locally (in any editor)
$EDITOR issues/SAR-123.md

# 6. See what changed
taskmate diff SAR-123

# 7. Improve with AI (optional)
taskmate improve SAR-123 --instruction "add acceptance criteria"

# 8. Push changes back to Jira
taskmate push SAR-123
```

---

## Commands

| Command | Description |
|---------|-------------|
| `taskmate init` | Initialize workspace in current directory |
| `taskmate doctor` | Run health checks (config, credentials, connectivity) |
| `taskmate pull <KEY>` | Pull issue from Jira to local Markdown file |
| `taskmate pull --jql "..."` | Pull multiple issues via JQL query |
| `taskmate push <KEY>` | Push local changes to Jira (with confirmation) |
| `taskmate push --dry-run <KEY>` | Show what would be pushed, no writes |
| `taskmate diff <KEY>` | Show diff vs last pulled version |
| `taskmate show <KEY>` | Display issue details |
| `taskmate improve <KEY>` | Improve issue description with AI |
| `taskmate review <KEY>` | Get AI review + readiness score |
| `taskmate draft "..."` | Create new local issue from description |
| `taskmate validate <KEY>` | Check Markdown is within supported subset |
| `taskmate workspace status` | Show sync status of all local issues |
| `taskmate conflict show <KEY>` | Show conflict details |
| `taskmate skills list` | List available skills |
| `taskmate version` | Print version |

---

## Configuration

### workspace.yml

Created by `taskmate init`. Committed to your repo (no secrets here).

```yaml
version: 1

tracker:
  kind: jira
  base_url: https://your-org.atlassian.net
  default_project: SAR

ai:
  provider: disabled   # openai | anthropic | ollama | disabled
  model: ""

security:
  require_consent_for_ai: true      # always ask before AI calls
  require_confirm_for_push: true    # always confirm before Jira writes
  secret_detection: true            # block if secrets found in content
  store_prompts_in_audit: false     # don't store raw prompts

push:
  allowed_fields:
    - summary
    - description
    - labels
    - components
    - priority
```

### Secrets (never in workspace.yml)

```bash
export TASKMATE_JIRA_URL=https://your-org.atlassian.net
export TASKMATE_JIRA_EMAIL=you@example.com
export TASKMATE_JIRA_TOKEN=your-api-token

# AI providers (set whichever you use)
export TASKMATE_OPENAI_API_KEY=sk-...
export TASKMATE_ANTHROPIC_API_KEY=sk-ant-...
```

### .taskmateignore

Gitignore-like file controlling what is **never sent to AI**:

```
*.key
*.pem
secrets.yml
.env
attachments/
```

---

## Workspace structure

```
workspace.yml           # config (committed)
.taskmateignore         # AI data exclusions (committed)

issues/
  SAR-123.md            # pulled issues (committed)
  new/
    2025-01-15-add-auth.md   # locally created, not yet in Jira
  conflicts/            # conflict snapshots
  .jira/               # reference copies + ADF backups (not committed)

reviews/
  SAR-123.review.md    # AI review output

skills/
  improve-task/
  review-task/
  create-task/

audit/
  actions/             # Jira write audit trail
  ai/                  # AI call audit trail
```

---

## Security model

- **No AI call without consent** — ConsentManager shows what will be sent and asks `y/N` (default N)
- **No Jira write without confirmation** — ActionGate shows the diff and asks `y/N` (default N)
- **Secret detection** — content is scanned for tokens, keys, credentials before any AI call
- **Audit trail** — every AI call and Jira write is logged to `audit/`
- **`.taskmateignore`** — exclude sensitive files from AI context
- **Offline by default** — most commands work without network

See [SECURITY.md](SECURITY.md) for full details.

---

## AI providers

| Provider | ENV variable | Model example |
|----------|-------------|---------------|
| OpenAI | `TASKMATE_OPENAI_API_KEY` | `gpt-4o` |
| Anthropic | `TASKMATE_ANTHROPIC_API_KEY` | `claude-opus-4-6` |
| Ollama | (none, local) | `llama3.2` |
| Disabled | (none) | — |

---

## Skills

Skills are Markdown files that define AI prompts and behavior. Built-in skills:

- **improve-task** — rewrite issue description, add acceptance criteria
- **review-task** — quality review + readiness score
- **create-task** — generate a new issue from a short description

Skills live in `skills/` and can be customized. Compare with built-in:

```bash
taskmate skills diff improve-task
```

---

## Examples

See the [`examples/`](examples/) directory for a pre-populated sample workspace
and an offline demo script you can run immediately without a real Jira connection:

```bash
bash examples/demo.sh
```

---

## Contributing

1. Fork the repo
2. `bundle install`
3. `bundle exec rspec`
4. Submit a PR

---

## License

MIT. See [LICENSE](LICENSE).
