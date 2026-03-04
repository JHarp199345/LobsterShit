#!/bin/bash
# 🦞 Harper SMS Directive Listener
# Polls iMessages sent FROM yourself TO yourself.
# Any message you text yourself is treated as a Harper directive.
# Run this in a background terminal: ./imsg_directive_listener.sh &
#
# Supported directives (same NL patterns as the chat UI):
#   "sort top 50 emails"
#   "filter last 2 hours of mail"
#   "clean all"
#   "status" — returns current mission state
#   "stop"   — halts any active mission

WORKSPACE="/Users/jesseharper/Documents/Workshop/workhorse"
TRIAGE="$WORKSPACE/scripts/harper_email_triage.sh"
PARSE="$WORKSPACE/scripts/harper_parse_directive.sh"
STATE_FILE="$WORKSPACE/mission_state.json"
SEEN_FILE="/tmp/harper_imsg_seen_ids"
MY_NUMBER="+12818810740"   # Your own phone number — edit if it changes
POLL_INTERVAL=30           # seconds between polls
DIAG_LOG="$WORKSPACE/turbo_diagnostic.log"

log_sms() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [imsg-listener] $1" >> "$DIAG_LOG"
}

touch "$SEEN_FILE"

log_sms "SMS Directive Listener started. Polling every ${POLL_INTERVAL}s for messages from $MY_NUMBER to $MY_NUMBER."

reply() {
    local msg="$1"
    imsg send --to "$MY_NUMBER" --text "$msg" 2>/dev/null || true
    log_sms "Replied: $msg"
}

while true; do
    # Fetch recent messages you sent to yourself (imsg history with own number, sent side)
    # imsg history returns JSON with id, text, isFromMe, date
    MESSAGES=$(imsg history --contact "$MY_NUMBER" --limit 10 --json 2>/dev/null \
        || imsg list --contact "$MY_NUMBER" --json 2>/dev/null \
        || echo "")

    if [ -z "$MESSAGES" ] || [ "$MESSAGES" = "null" ] || [ "$MESSAGES" = "[]" ]; then
        sleep "$POLL_INTERVAL"
        continue
    fi

    # Process each message sent FROM yourself that we haven't seen yet
    echo "$MESSAGES" | jq -c '.[] | select(.isFromMe == true or .from_me == true)' 2>/dev/null \
    | while IFS= read -r msg; do
        MSG_ID=$(echo "$msg" | jq -r '.id // .guid // empty' 2>/dev/null)
        MSG_TEXT=$(echo "$msg" | jq -r '.text // .body // empty' 2>/dev/null | tr '[:upper:]' '[:lower:]' | xargs)

        [ -z "$MSG_ID" ] && continue
        [ -z "$MSG_TEXT" ] && continue

        # Skip already-processed messages
        if grep -qxF "$MSG_ID" "$SEEN_FILE"; then
            continue
        fi
        echo "$MSG_ID" >> "$SEEN_FILE"

        log_sms "New directive from self: '$MSG_TEXT'"

        # ── STATUS ──────────────────────────────────────────────────────────
        if echo "$MSG_TEXT" | grep -qE '^status$'; then
            if [ -f "$STATE_FILE" ]; then
                PROG=$(jq -r '"In progress: \(.processed_count)/\(.total_items) (\(.status))"' "$STATE_FILE" 2>/dev/null)
                reply "🦞 Harper: $PROG"
            else
                reply "🦞 Harper: No active mission. Inbox idle."
            fi
            continue
        fi

        # ── STOP ────────────────────────────────────────────────────────────
        if echo "$MSG_TEXT" | grep -qE '^stop$'; then
            if [ -f "$STATE_FILE" ]; then
                rm -f "$STATE_FILE"
                reply "🦞 Harper: Mission stopped."
                log_sms "Mission stopped via SMS directive."
            else
                reply "🦞 Harper: Nothing running to stop."
            fi
            continue
        fi

        # ── EMAIL TRIAGE DIRECTIVE ───────────────────────────────────────
        if echo "$MSG_TEXT" | grep -qE '(email|mail|inbox|sort|triage|clean|filter|organize)'; then
            ARGS=$("$PARSE" "$MSG_TEXT" 2>/dev/null)
            if [ -z "$ARGS" ]; then
                reply "🦞 Harper: Couldn't parse that directive. Try: 'sort top 50 emails'"
                continue
            fi

            log_sms "Launching triage with args: $ARGS"
            reply "🦞 Harper: Got it — starting email mission. Will text you when done."

            # Run triage in background so listener keeps polling
            # shellcheck disable=SC2086
            nohup bash "$TRIAGE" $ARGS >> "$DIAG_LOG" 2>&1 &
            continue
        fi

        # ── UNRECOGNIZED ────────────────────────────────────────────────
        log_sms "Unrecognized directive: '$MSG_TEXT'"
        reply "🦞 Harper: Didn't recognize that. Try: 'sort top 50 emails' or 'status'"
    done

    sleep "$POLL_INTERVAL"
done
