#!/bin/bash
# 🦞 HARPER EMAIL TRIAGE - CLI Form
# Mission: Interactive form OR non-interactive (--total --batches --approve-all for chat/tool use).
# Everything else hardcoded. Works 100% through CLI.

WORKSPACE="/Users/jesseharper/Documents/Workshop/workhorse"
ARCHITECT="$WORKSPACE/scripts/task_architect.sh"
STATE_FILE="$WORKSPACE/mission_state.json"

# Parse args for non-interactive (tool/chat) mode
NON_INTERACTIVE=0
TOTAL_ARG=""
BATCHES_ARG=""
APPROVE_ALL_ARG=0
SINCE_ARG=""    # Unix epoch timestamp for time-based missions
BOTTOM_ARG=""   # If set, process oldest emails first

while [[ $# -gt 0 ]]; do
    case $1 in
        --total) TOTAL_ARG="$2"; shift 2 ;;
        --batches) BATCHES_ARG="$2"; shift 2 ;;
        --approve-all) APPROVE_ALL_ARG=1; shift ;;
        --since) SINCE_ARG="$2"; shift 2 ;;
        --bottom) BOTTOM_ARG="--bottom"; shift ;;
        *) TOTAL_ARG="$1"; shift ;;
    esac
done

# Non-interactive: params from CLI/agent (--total+--batches OR --since+--batches)
if ([ -n "$TOTAL_ARG" ] || [ -n "$SINCE_ARG" ]) && [ -n "$BATCHES_ARG" ]; then
    NON_INTERACTIVE=1
    TOTAL_RAW="${TOTAL_ARG:-time-based}"
    BATCHES=${BATCHES_ARG:-2}
    APPROVE_ALL=$APPROVE_ALL_ARG
fi

# --- FORM: Collect params (interactive) or use args (non-interactive) ---
if [ "$NON_INTERACTIVE" -eq 0 ]; then
    echo ""
    echo "═══ 🦞 HARPER EMAIL TRIAGE ═══"
    echo ""

    # 1. Total emails (from positional arg or prompt)
    TOTAL_RAW="${TOTAL_ARG}"
    if [ -z "$TOTAL_RAW" ]; then
        printf " How many emails? (number or 'all'): "
        read -r TOTAL_RAW
    fi
    if [ -z "$TOTAL_RAW" ]; then
        echo "No value provided. Exiting."
        exit 1
    fi

    # 2. Number of batches
    printf " Number of batches? (default 2): "
    read -r batches_input
    BATCHES=${batches_input:-2}
    if ! [[ "$BATCHES" =~ ^[0-9]+$ ]] || [ "$BATCHES" -lt 1 ]; then
        BATCHES=2
    fi

    # 3. Approve all batches at once?
    printf " Approve all batches at once? (y/n): "
    read -r approve_all
    APPROVE_ALL=0
    [[ "$approve_all" =~ ^[yY] ]] && APPROVE_ALL=1

    echo ""
    echo "────────────────────────────────────"
    echo " Starting triage: $TOTAL_RAW emails, $BATCHES batches"
    echo "────────────────────────────────────"
    echo ""
fi

# Parse "all" / "everything"
TOTAL_RAW_LOWER=$(echo "$TOTAL_RAW" | tr '[:upper:]' '[:lower:]')
if [[ "$TOTAL_RAW_LOWER" == "all" || "$TOTAL_RAW_LOWER" == "everything" ]]; then
    TOTAL="all"
else
    if ! [[ "$TOTAL_RAW" =~ ^[0-9]+$ ]] || [ "$TOTAL_RAW" -lt 1 ]; then
        echo "Invalid. Use a number or 'all'."
        exit 1
    fi
    TOTAL="$TOTAL_RAW"
fi

if [ "$NON_INTERACTIVE" -eq 0 ] && [ "$TOTAL" != "all" ]; then
    BATCH_SIZE=$(( (TOTAL + BATCHES - 1) / BATCHES ))
    [ "$BATCH_SIZE" -lt 1 ] && BATCH_SIZE=1
    echo "  → Batch size: $BATCH_SIZE emails per batch"
    echo ""
fi

# --- Run architect: init (creates state) ---
if [ -n "$SINCE_ARG" ]; then
    # shellcheck disable=SC2086
    $ARCHITECT --since "$SINCE_ARG" --batches "$BATCHES" $BOTTOM_ARG || exit 1
else
    # shellcheck disable=SC2086
    $ARCHITECT "$TOTAL" --batches "$BATCHES" $BOTTOM_ARG || exit 1
fi

if [ ! -f "$STATE_FILE" ]; then
    echo "No emails to process (inbox empty or already complete)."
    exit 0
fi

# --- Set approved if user said yes ---
if [ "$APPROVE_ALL" -eq 1 ]; then
    STATE=$(cat "$STATE_FILE")
    echo "$STATE" | jq '.approved = true' > "$STATE_FILE"
    echo "✓ Approved for all batches."
    echo ""
fi

# --- Run in foreground until done (architect --loop exec's itself until complete) ---
# If not approved, architect will exit; we prompt and re-run
while [ -f "$STATE_FILE" ]; do
    APPROVED=$(jq -r '.approved' "$STATE_FILE" 2>/dev/null)
    if [ "$APPROVED" != "true" ]; then
        printf " APPROVE next batch? (y/n): "
        read -r ans
        if [[ "$ans" =~ ^[yY] ]]; then
            STATE=$(cat "$STATE_FILE")
            echo "$STATE" | jq '.approved = true' > "$STATE_FILE"
        else
            echo "Mission paused. Run this script again to continue, or delete $STATE_FILE to cancel."
            exit 0
        fi
    fi

    # Architect --loop runs until complete (exec's itself for each batch)
    $ARCHITECT --loop
    [ ! -f "$STATE_FILE" ] && break
done

echo ""
echo "✓ Triage complete."
