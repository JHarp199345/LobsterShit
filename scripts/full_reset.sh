#!/bin/bash
# 🦞 FULL RESET - Kill all Harper/OpenClaw processes and wipe state.
# Enforces single-instance: unloads launchd, kills every OpenClaw-related process.
# Use when: TUI stuck, approval timed out, architect orphaned, or you want a clean slate.

WORKSPACE="${WORKSPACE:-/Users/jesseharper/Documents/Workshop/workhorse}"
STATE_FILE="$WORKSPACE/mission_state.json"
PLIST="$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist"

echo "🛑 Full Reset: enforcing single instance, killing all OpenClaw processes..."

# 0. Unload and remove launchd service (stops persistent gateway, prevents respawn/restart)
if [ -f "$PLIST" ]; then
    launchctl unload "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
fi

# 1. Kill by process name (killall -9)
killall -9 task_architect.sh 2>/dev/null || true
killall -9 turbo_cleaner_v3.sh 2>/dev/null || true
killall -9 openclaw-gateway 2>/dev/null || true
killall -9 openclaw 2>/dev/null || true

# 2. Kill node processes running OpenClaw (gateway, TUI, agent, approval watcher)
# launchd runs: node .../openclaw/dist/index.js gateway
pkill -9 -f "openclaw.*gateway" 2>/dev/null || true
pkill -9 -f "index.js.*gateway" 2>/dev/null || true
pkill -9 -f "approval-watcher" 2>/dev/null || true
pkill -9 -f "openclaw.*tui" 2>/dev/null || true
pkill -9 -f "openclaw.*agent" 2>/dev/null || true
pkill -9 -f "openclaw-core.*harper" 2>/dev/null || true

# 3. Remove mission state (architect will think nothing is in progress)
rm -f "$STATE_FILE" 2>/dev/null || true

# 4. Clean locks, PIDs, sockets
rm -f /Users/jesseharper/.openclaw/agents/main/sessions/*.lock 2>/dev/null || true
rm -f /Users/jesseharper/.openclaw/agents/main/sessions/*.pid 2>/dev/null || true
rm -f /tmp/openclaw*.pid /tmp/openclaw*.lock 2>/dev/null || true
rm -f /tmp/mission_batch_*.queue /tmp/turbo_results_* 2>/dev/null || true
rm -f /Users/jesseharper/.openclaw/exec-approvals.sock 2>/dev/null || true
rm -f "$WORKSPACE"/*.pid 2>/dev/null || true

echo "✓ Full reset complete. Fresh state. Run command center or openclaw tui to start again."
