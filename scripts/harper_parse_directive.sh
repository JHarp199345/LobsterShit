#!/bin/bash
# 🦞 Harper Directive Parser
# Converts a natural language email command into harper_email_triage.sh arguments.
# Usage: harper_parse_directive.sh "sort through top 100 emails"
# Output: args string, e.g. "--total 100 --batches 10 --approve-all"
#         or "--since 1709000000 --batches 5 --approve-all" for time-based
#
# Called by the AI agent and imsg_directive_listener.sh.

INPUT="${1:-}"
LOWER=$(echo "$INPUT" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 .-]/ /g')

# ── COUNT EXTRACTION ──────────────────────────────────────────────────────────
# Matches: "top 100", "last 28", "first 50", "100 emails", "28 messages", "next 10"
COUNT=""

if echo "$LOWER" | grep -qE '\b(all|everything|entire inbox|inbox)\b'; then
    COUNT="all"
elif echo "$LOWER" | grep -qE '\b(top|last|first|next|recent)\s+([0-9]+)\b'; then
    COUNT=$(echo "$LOWER" | grep -oE '\b(top|last|first|next|recent)\s+([0-9]+)\b' \
        | grep -oE '[0-9]+' | head -1)
elif echo "$LOWER" | grep -qE '\b[0-9]+\s+(email|mail|message|thread)\b'; then
    COUNT=$(echo "$LOWER" | grep -oE '\b[0-9]+\s+(email|mail|message|thread)\b' \
        | grep -oE '^[0-9]+' | head -1)
elif echo "$LOWER" | grep -qE '\b[0-9]+\b'; then
    # Bare number: only use if it's standalone (not part of a time expression)
    if ! echo "$LOWER" | grep -qE '\b[0-9]+\s*(hours?|hrs?|minutes?|mins?|seconds?)\b'; then
        COUNT=$(echo "$LOWER" | grep -oE '\b[0-9]+\b' | head -1)
    fi
fi

# ── TIME-BASED EXTRACTION ─────────────────────────────────────────────────────
# Matches: "past 2 hours", "last 30 minutes", "received in the past 2 hours"
SINCE=""

if echo "$LOWER" | grep -qE '\b(past|last)\s+([0-9]+)\s+(hours?|hrs?|minutes?|mins?)\b'; then
    AMOUNT=$(echo "$LOWER" \
        | grep -oE '\b(past|last)\s+([0-9]+)\s+(hours?|hrs?|minutes?|mins?)\b' \
        | grep -oE '[0-9]+' | head -1)
    UNIT=$(echo "$LOWER" \
        | grep -oE '\b(past|last)\s+([0-9]+)\s+(hours?|hrs?|minutes?|mins?)\b' \
        | grep -oE '(hours?|hrs?|minutes?|mins?)' | head -1)
    case "$UNIT" in
        hour|hours|hr|hrs)     SECONDS=$((AMOUNT * 3600)) ;;
        minute|minutes|min|mins) SECONDS=$((AMOUNT * 60)) ;;
        *) SECONDS=3600 ;;
    esac
    # macOS date -v vs GNU date -d
    SINCE=$(date -v -${SECONDS}S +%s 2>/dev/null \
        || date -d "-${SECONDS} seconds" +%s 2>/dev/null \
        || echo "")
fi

# "today" → midnight local time
if [ -z "$SINCE" ] && echo "$LOWER" | grep -qE '\btoday\b'; then
    SINCE=$(date -v 0H -v 0M -v 0S +%s 2>/dev/null \
        || date -d "today 00:00:00" +%s 2>/dev/null \
        || echo "")
fi

# ── BATCH SIZING ──────────────────────────────────────────────────────────────
auto_batches() {
    local n="$1"
    if [ "$n" = "all" ]; then echo 20
    elif [ "$n" -le 10 ]  2>/dev/null; then echo 1
    elif [ "$n" -le 30 ]  2>/dev/null; then echo 3
    elif [ "$n" -le 100 ] 2>/dev/null; then echo 10
    else echo 20
    fi
}

# ── OUTPUT ────────────────────────────────────────────────────────────────────
if [ -n "$SINCE" ]; then
    # Time-based: ignore count, pass --since to task_architect
    BATCHES=$(auto_batches 50)
    echo "--since $SINCE --batches $BATCHES --approve-all"
elif [ -n "$COUNT" ]; then
    BATCHES=$(auto_batches "$COUNT")
    echo "--total $COUNT --batches $BATCHES --approve-all"
else
    # Fallback: process 50 most recent unread
    echo "--total 50 --batches 5 --approve-all"
fi
