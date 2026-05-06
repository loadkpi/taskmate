#!/usr/bin/env bash
# Taskmate demo — runs end-to-end workflow without a real Jira connection.
# Uses the sample workspace in examples/workspace/ with fake data.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR/workspace"
TASKMATE="${SCRIPT_DIR}/../exe/taskmate"

echo "=== Taskmate Demo (offline mode) ==="
echo

# Show workspace status
echo "--- workspace status ---"
"$TASKMATE" workspace status
echo

# Show a pulled issue
echo "--- show DEMO-1 ---"
"$TASKMATE" show DEMO-1 --format text
echo

# Show diff for the locally-modified issue
echo "--- diff DEMO-2 (local changes) ---"
"$TASKMATE" diff DEMO-2 || true
echo

# Validate Markdown compatibility
echo "--- validate DEMO-1 ---"
"$TASKMATE" validate DEMO-1
echo

# Show the new local issue (not yet in Jira)
echo "--- show new local draft ---"
DRAFT=$(ls "$WORKSPACE/issues/new/"*.md 2>/dev/null | head -1)
if [[ -n "$DRAFT" ]]; then
  "$TASKMATE" show "$DRAFT"
fi
echo

# List skills
echo "--- skills list ---"
"$TASKMATE" skills list
echo

echo "=== Demo complete ==="
echo
echo "Next steps:"
echo "  export TASKMATE_JIRA_URL=https://your-org.atlassian.net"
echo "  export TASKMATE_JIRA_EMAIL=you@example.com"
echo "  export TASKMATE_JIRA_TOKEN=your-api-token"
echo "  taskmate doctor"
echo "  taskmate pull PROJ-123"
