#!/bin/bash
# 🦞 UNINSTALL PERSISTENCE - Remove launchd service so OpenClaw never auto-starts.
# Run once to disable KeepAlive/RunAtLoad. Gateway will no longer respawn or start on login.
# Use "openclaw gateway run" (foreground) or command center option 4 to start manually.

PLIST="$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist"

echo "🛑 Uninstalling OpenClaw persistence..."

if [ -f "$PLIST" ]; then
    launchctl unload "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
    echo "✓ Removed $PLIST"
else
    echo "  (No plist found - already uninstalled)"
fi

echo "✓ Persistence removed. OpenClaw will not auto-start. Use command center or 'openclaw gateway run' to start manually."
