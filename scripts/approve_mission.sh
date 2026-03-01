#!/bin/bash
# 🦞 HARPER MISSION APPROVAL v1.0
# Mission: Fast macOS Pop-up for Mission Authorization.

TOTAL_EMAILS=$1
BATCH_SIZE=${2:-10}

if [ -z "$TOTAL_EMAILS" ]; then
    echo "Usage: $0 <total_emails> [batch_size]"
    exit 1
fi

TITLE="🦞 HARPER MISSION CONTROL"
MESSAGE="Initiating Email Scan & Triage.
------------------------------------
Total Emails: $TOTAL_EMAILS
Batch Size:   $BATCH_SIZE
Orchestration: Persistent Worker (State-Machine)

Do you authorize this mission?"

# AppleScript pop-up
RESULT=$(osascript -e "button returned of (display dialog \"$MESSAGE\" with title \"$TITLE\" buttons {\"Deny\", \"Approve\"} default button \"Approve\" with icon note)" 2>/dev/null)

if [ "$RESULT" == "Approve" ]; then
    echo "APPROVED"
    exit 0
else
    echo "DENIED"
    exit 1
fi
