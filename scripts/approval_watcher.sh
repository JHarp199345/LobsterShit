#!/bin/bash
# CLI Approval Watcher - Aider-style approval prompts in the terminal.
# Run in a split pane alongside the TUI (Option 4) for instant approval feedback.
# When the AI requests exec approval, this script prints the command in bold red
# and prompts APPROVE? (y/n/a=allow-always) directly in your CLI.
#
# Usage: ./scripts/approval_watcher.sh
# Or in a split pane: tmux split -h; ./scripts/approval_watcher.sh
#
# IMPORTANT: Start Option 4 (TUI) or the gateway first. The watcher connects to
# the gateway at ws://127.0.0.1:18789. If you get ECONNREFUSED, the gateway isn't running.

set -e
WORKSPACE="${WORKSPACE:-/Users/jesseharper/Documents/Workshop/workhorse}"
OC_CORE="$WORKSPACE/openclaw-core"
MAX_RETRIES=3
RETRY_DELAY=2

run_watcher() {
  if [ -f "$OC_CORE/package.json" ]; then
    (cd "$OC_CORE" && pnpm run approval-watch 2>/dev/null) && return 0
    (cd "$OC_CORE" && npm run approval-watch 2>/dev/null) && return 0
  fi
  if [ -f "$OC_CORE/scripts/approval-watcher.mjs" ]; then
    (cd "$OC_CORE" && node scripts/approval-watcher.mjs) && return 0
  fi
  # Use local openclaw (has approval-watch) instead of global (may be older)
  if [ -f "$OC_CORE/openclaw.mjs" ]; then
    (cd "$OC_CORE" && node openclaw.mjs approval-watch 2>/dev/null) && return 0
  fi
  return 1
}

for attempt in $(seq 1 $MAX_RETRIES); do
  if [ $attempt -gt 1 ]; then
    echo "[approval-watcher] Retry $attempt/$MAX_RETRIES in ${RETRY_DELAY}s..." >&2
    sleep $RETRY_DELAY
  fi
  if run_watcher; then
    exit 0
  fi
  EXIT=$?
done

echo "" >&2
echo "Error: approval-watcher could not connect. Ensure the gateway is running:" >&2
echo "  • Run Option 4 (TUI) first, then Option 4b in a split pane" >&2
echo "  • Or: openclaw gateway start" >&2
echo "  • Run: cd $OC_CORE && pnpm install (if deps missing)" >&2
exit 1
