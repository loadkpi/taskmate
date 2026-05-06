# Taskmate Examples

This directory contains a sample workspace and demo script to help you get started.

## Sample workspace

`examples/workspace/` is a pre-populated Taskmate workspace with:

| File | Description |
|------|-------------|
| `workspace.yml` | Sample configuration (edit before use) |
| `.taskmateignore` | Sample exclusion rules |
| `issues/DEMO-1.md` | A clean (synced) issue |
| `issues/DEMO-2.md` | An issue with local changes |
| `issues/new/2025-05-01-add-rate-limiting.md` | A locally-drafted issue, not yet in Jira |

## Demo script

Run an offline demo of the full workflow (no Jira needed):

```bash
cd /path/to/taskmate
bash examples/demo.sh
```

The script uses the sample workspace and calls taskmate commands to show:
- Workspace status
- Issue display
- Diff
- Markdown validation
- Skills list

## Using with real Jira

1. Copy `examples/workspace/workspace.yml` to your project directory
2. Edit `jira.base_url` and `jira.default_project`
3. Run `taskmate init` (or use the config directly)
4. Set credentials:
   ```bash
   export TASKMATE_JIRA_URL=https://your-org.atlassian.net
   export TASKMATE_JIRA_EMAIL=you@example.com
   export TASKMATE_JIRA_TOKEN=your-api-token
   ```
5. Run `taskmate doctor` to verify setup
6. Run `taskmate pull PROJ-123` to pull your first issue
