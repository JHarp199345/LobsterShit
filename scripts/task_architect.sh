#!/bin/bash
# 🦞 OPERATION HIGH-SPEED: v6.0 - THE STATE-MACHINE WORKER
# Mission: Shell-Driven Loop Orchestration with External Approval.
# Pattern: State-First -> Batch (10) -> Recursive Execution.

WORKSPACE="/Users/jesseharper/Documents/Workshop/workhorse"
STATE_FILE="$WORKSPACE/mission_state.json"
CLEANER="$WORKSPACE/scripts/turbo_cleaner_v3.sh"
APPROVER="$WORKSPACE/scripts/approve_mission.sh"
DIAG_LOG="$WORKSPACE/turbo_diagnostic.log"

# Source unified logger
if [ -f "$WORKSPACE/scripts/lib/logger.sh" ]; then
    source "$WORKSPACE/scripts/lib/logger.sh"
    log_worker() { harper_log INFO architect "$1"; }
else
    log_worker() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🤖 Worker: $1" >> "$DIAG_LOG"
    }
fi

chmod +x "$APPROVER"

# 1. INITIALIZATION & ARG PARSING
LOOP_MODE=0
APPROVE_MODE=0
GOAL=100
BATCH_LIMIT=10
BATCH_COUNT=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --loop) LOOP_MODE=1 ;;
        --approve) APPROVE_MODE=1 ;;
        --batch-size) BATCH_LIMIT="${2:-10}"; shift ;;
        --batches) BATCH_COUNT="${2:-2}"; shift ;;
        all|everything) GOAL="all" ;;
        [0-9]*) GOAL="$1" ;;
    esac
    shift
done

# If approve mode is set, just mark it and exit
if [ "$APPROVE_MODE" -eq 1 ]; then
    if [ -f "$STATE_FILE" ]; then
        log_worker "Approving existing mission state..."
        STATE=$(cat "$STATE_FILE")
        echo "$STATE" | jq '.approved = true' > "$STATE_FILE"
        echo "{\"status\": \"Approved\", \"message\": \"Mission authorized. Proceeding with batches.\"}"
        exit 0
    else
        log_worker "Error: Cannot approve. No mission state found."
        echo "{\"status\": \"Error\", \"message\": \"No mission state found to approve.\"}"
        exit 1
    fi
fi

if [ ! -f "$STATE_FILE" ]; then
    # "all" = fetch everything (high limit); otherwise use GOAL as limit
    GOG_MAX="$GOAL"
    [ "$GOAL" = "all" ] && GOG_MAX=10000
    
    log_worker "No mission state found. Initializing for $GOAL emails..."
    
    ALL_IDS_JSON=$(gog gmail search 'is:unread' --max "$GOG_MAX" --json)
    IDS=$(echo "$ALL_IDS_JSON" | jq -c '.threads | map(.id)' 2>/dev/null)
    
    # Fallback to sed if jq fails to parse gog output
    if [ -z "$IDS" ] || [ "$IDS" == "null" ] || [ "$IDS" == "[]" ]; then
        RAW_IDS=$(echo "$ALL_IDS_JSON" | sed -n 's/.*"id": "\([^"]*\)".*/\1/p' | head -n "$GOG_MAX")
        if [ -n "$RAW_IDS" ]; then
            IDS=$(echo "$RAW_IDS" | jq -R . | jq -s -c .)
        else
            IDS="[]"
        fi
    fi
    
    if [ "$IDS" == "[]" ]; then
        echo "{\"status\": \"Complete\", \"message\": \"Inbox is already clean.\"}"
        exit 0
    fi
    
    TOTAL=$(echo "$IDS" | jq '. | length')
    
    # If --batches was passed, compute batch_size from actual total
    if [ "$BATCH_COUNT" -gt 0 ]; then
        BATCH_LIMIT=$(( (TOTAL + BATCH_COUNT - 1) / BATCH_COUNT ))
        [ "$BATCH_LIMIT" -lt 1 ] && BATCH_LIMIT=1
    fi
    
    cat <<EOF > "$STATE_FILE"
{
  "total_items": $TOTAL,
  "processed_count": 0,
  "remaining_ids": $IDS,
  "status": "In-Progress",
  "approved": false,
  "batch_size": $BATCH_LIMIT
}
EOF
    log_worker "Mission State created: $TOTAL emails to process. [Approved: false]"
    
    # INITIALIZATION COMPLETE - WAIT FOR AGENTIC APPROVAL
    log_worker "Mission Initialized. Waiting for Agentic Approval (approved: false)."
    echo "{\"status\": \"Pending-Approval\", \"total_items\": $TOTAL, \"message\": \"Mission for $TOTAL emails initialized. Please authorize to proceed.\"}"
    exit 0
fi

# 2. BATCH EXECUTION
STATE=$(cat "$STATE_FILE")
APPROVED=$(echo "$STATE" | jq -r '.approved')
TOTAL=$(echo "$STATE" | jq -r '.total_items')
PROCESSED=$(echo "$STATE" | jq -r '.processed_count')
REMAINING_IDS=$(echo "$STATE" | jq -c '.remaining_ids')
# Use batch_size from state (preserved across exec) or fallback to script default
EFFECTIVE_BATCH=$(echo "$STATE" | jq -r '.batch_size // '"$BATCH_LIMIT")

# Check Approval again just in case it was set externally
if [ "$APPROVED" != "true" ]; then
    log_worker "Mission not yet approved. Waiting for external authorization."
    exit 0
fi

# Pull next batch
BATCH=$(echo "$REMAINING_IDS" | jq -c ".[:$EFFECTIVE_BATCH]")
BATCH_SIZE=$(echo "$BATCH" | jq '. | length')

if [ "$BATCH_SIZE" -eq 0 ]; then
    log_worker "Mission Complete. $PROCESSED/$TOTAL processed."
    rm -f "$STATE_FILE"
    echo "{\"status\": \"Complete\", \"message\": \"All $TOTAL emails processed successfully.\"}"
    exit 0
fi

# Save batch to temporary file for cleaner
TMP_QUEUE="/tmp/mission_batch_$$.queue"
echo "$BATCH" | jq -r '.[]' > "$TMP_QUEUE"

log_worker "Executing batch of $BATCH_SIZE (Remaining: $(echo "$REMAINING_IDS" | jq '. | length'))"
$CLEANER --queue "$TMP_QUEUE" --silent --worker
rm -f "$TMP_QUEUE"

# 3. UPDATE STATE
NEW_PROCESSED=$((PROCESSED + BATCH_SIZE))
NEW_REMAINING_IDS=$(echo "$REMAINING_IDS" | jq -c ".[$EFFECTIVE_BATCH:]")

cat <<EOF > "$STATE_FILE"
{
  "total_items": $TOTAL,
  "processed_count": $NEW_PROCESSED,
  "remaining_ids": $NEW_REMAINING_IDS,
  "status": "In-Progress",
  "approved": true,
  "batch_size": $EFFECTIVE_BATCH
}
EOF

# 4. PULSE SELF-TRIGGER (The Shell-Loop)
if [ "$NEW_PROCESSED" -ge "$TOTAL" ] || [ "$(echo "$NEW_REMAINING_IDS" | jq '. | length' 2>/dev/null)" -eq 0 ]; then
    log_worker "Mission Complete. $NEW_PROCESSED/$TOTAL processed."
    rm -f "$STATE_FILE"
    echo "{\"status\": \"Complete\", \"message\": \"Mission Complete! All $NEW_PROCESSED emails handled.\"}"
elif [ "$LOOP_MODE" -eq 1 ]; then
    # Foreground Shell Loop (The State-Machine) - batch_size in state, no need to pass
    log_worker "Pulse Trigger: Continuing Mission Loop... ($NEW_PROCESSED/$TOTAL)"
    exec "$0" --loop
else
    # Agent-Driven Self-Trigger (Fallback)
    echo "{\"status\": \"In-Progress\", \"batch_complete\": $BATCH_SIZE, \"progress\": \"$NEW_PROCESSED/$TOTAL\", \"next_command\": \"$0\"}"
fi
