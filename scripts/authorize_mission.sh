#!/bin/bash
# 🦞 HARPER MISSION AUTHORIZATION
# Mission: Set mission_state.json to approved: true via OpenClaw UI button.

STATE_FILE="/Users/jesseharper/Documents/Workshop/workhorse/mission_state.json"

if [ -f "$STATE_FILE" ]; then
    # Use jq to update the state file
    STATE=$(cat "$STATE_FILE")
    echo "$STATE" | jq '.approved = true' > "$STATE_FILE"
    echo "SUCCESS: Mission has been authorized by Jesse Harper."
    exit 0
else
    echo "ERROR: No mission state found to authorize. Run task_architect first."
    exit 1
fi
