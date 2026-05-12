# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-05-12

First public release.

### Added

**CLI commands**
- `taskmate init` — interactive workspace setup; creates directory structure, `workspace.yml`, `.taskmateignore`, copies built-in skills; supports `--non-interactive`
- `taskmate doctor` — extensible health-check system (workspace, directories, skills, secrets, security config, Jira connectivity, AI provider)
- `taskmate pull SAR-123` / `taskmate pull --jql "..." --limit N` — pull issues from Jira Cloud to local Markdown files
- `taskmate push SAR-123` — push local changes back to Jira with conflict detection, field-level diff, confirmation prompt, and dry-run mode (`--dry-run`)
- `taskmate show SAR-123` — display issue fields and body; `--metadata` shows all frontmatter; `--format json`
- `taskmate diff SAR-123` — unified diff between current file and last-pulled synced copy; works offline
- `taskmate validate SAR-123` — check Markdown for unsupported Jira features before push; `--format json`
- `taskmate workspace status` — offline scan of all issues grouped by sync state
- `taskmate improve SAR-123` — AI-powered issue improvement with diff preview and apply/discard prompt; `--instruction "..."`, `--output file.md`
- `taskmate review SAR-123` — AI-powered issue review; writes `reviews/<KEY>.review.md` with readiness score
- `taskmate create-task "description"` / `taskmate draft "description"` — AI-assisted creation of new local issues
- `taskmate conflict show SAR-123` — explain Jira-side changes; `pull --save-as-conflict` / `pull --overwrite-local` for resolution
- `taskmate skills list/show/validate/diff` — manage and inspect skills in the workspace

**Workspace engine**
- YAML frontmatter parser/serializer with round-trip stability
- `IssueFile` model — read/write Markdown issue files; structured `assignee`/`reporter` objects
- `CanonicalHash` — SHA-256 over deterministic content (excludes timestamps, status, sync fields)
- Dynamic `SyncState` — computed from hashes: `clean`, `local_changed`, `jira_changed`, `conflict`, `new_local`
- Synced reference copies (`issues/.jira/<KEY>.synced.md`) for offline diff
- `.taskmateignore` parser with gitignore-like syntax (wildcards, directory patterns including multi-component paths)

**Security pipeline**
- `SecretRedactor` — detects AWS keys, JWT tokens, GitHub/GitLab tokens, private keys, URL credentials, generic `api_key=...` patterns; replaces with `[REDACTED]`
- `DataClassifier` — classifies content as `safe`/`sensitive`/`secret`/`excluded` before any AI call
- `ConsentManager` — shows disclosure and asks `[y/N]` before every external AI call; auto-denies in non-interactive mode
- `ActionGate` — shows field-level diff and action plan before every Jira write; auto-denies in non-interactive mode
- `AuditWriter` — writes timestamped YAML audit files to `audit/actions/` and `audit/ai/`; never stores raw prompts or secrets by default

**Jira integration**
- Faraday-based Jira Cloud REST API v3 client; retry with exponential backoff for reads, no retry for writes
- ADF → Markdown converter (headings, paragraphs, lists, code blocks, bold/italic/code marks, links); unsupported nodes emit HTML comment placeholders
- ADF backup saved to `issues/.jira/<KEY>.description.adf.json` when unsupported nodes are detected
- Markdown → ADF converter for the push direction
- `PayloadBuilder` — allowlist-based field filtering (fail-closed: unknown fields are excluded)
- Hash-based conflict detector to block push when Jira changed since last pull

**AI providers**
- `AI::Client.from_config` — selects provider from `workspace.yml`: `openai`, `anthropic`, `ollama`, or `fake`
- OpenAI Chat Completions, Anthropic Messages API, local Ollama — all with consistent timeout handling (10s connect, 120s read)
- `FakeProvider` for tests — deterministic responses, no network calls, records calls for assertions

**Skills engine**
- Skill loader, validator, registry, and differ
- Built-in skills: `create-task`, `improve-task`, `review-task`
- Skills are copied to `skills/` on `init` and can be customized per workspace

**Other**
- `--format json` output on all key commands
- Shared `CLI::ErrorHandling` module with typed exit codes (0 success/cancel, 1 error, 2 validation, 3 conflict, 4 auth)
- `examples/` sample workspace with demo script
- Full integration test suite: pull→edit→validate→diff→push workflow, conflict workflow, new-task workflow, offline commands

### Fixed
- `IgnoreRules` multi-component directory patterns (e.g. `issues/private/`) now match correctly
- `DataClassifier#highest_level` replaced non-existent `Array#rfind` with `reverse.find`
- `PayloadBuilder#allow?` defaults to `false` (fail-closed)
- Config readers use dual-key fallback (`tracker.*` with `jira.*` as legacy alias)
- README Ruby version requirement corrected to >= 3.3

[0.1.0]: https://github.com/your-org/taskmate/releases/tag/v0.1.0
