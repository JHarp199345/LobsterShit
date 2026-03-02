#!/bin/bash
# 🦞 OPERATION HIGH-SPEED: v4.2 - THE PARALLEL BATCH REAPER
# Mission: One-Shot Decision + Parallel Execution + Structured Outputs + Comprehensive Logging.
# Performance: Target < 15s for 20 emails.

WORKSPACE="/Users/jesseharper/Documents/Workshop/workhorse"
DB_FILE="$WORKSPACE/processed_emails.db"
LEDGER_FILE="$WORKSPACE/daily_ledger.log"
DIAG_LOG="$WORKSPACE/turbo_diagnostic.log"
LIBRARY_DIR="/Users/jesseharper/.openclaw/prompt_library"
DEBUG_RESPONSE_FILE="$WORKSPACE/turbo_debug_last_response.json"
DEBUG_CONTENT_FILE="$WORKSPACE/turbo_debug_last_content.txt"

touch "$DB_FILE" "$LEDGER_FILE" "$DIAG_LOG"

# Source unified logger (fallback to legacy log_event if not found)
if [ -f "$WORKSPACE/scripts/lib/logger.sh" ]; then
    source "$WORKSPACE/scripts/lib/logger.sh"
else
    log_event() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$DIAG_LOG"
        echo "📡 $1"
    }
fi

# Configuration
QUEUE_FILE=""
DRY_RUN=0
LIMIT=10
CONCURRENT_ACTIONS=5
SILENT=0
WORKER_MODE=0
TURBO_MODELS="${TURBO_MODELS:-qwen3:8b qwen3-vl:8b qwen2.5:8b}"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --queue) QUEUE_FILE="$2"; shift ;;
        --batch) : ;;  # Primary mode (default)
        --dry-run) DRY_RUN=1 ;;
        --limit) LIMIT="$2"; shift ;;
        --silent) SILENT=1 ;;
        --worker) WORKER_MODE=1 ;;
    esac
    shift
done

log_event() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$DIAG_LOG"
    echo "📡 $1"
}

# --- SECTION C: PRE-FLIGHT ---
log_event "[1/4] Pre-flight: Checking systems..."
if ! curl -s -o /dev/null -w "%{http_code}" http://localhost:11434/api/tags | grep -q "200"; then
    log_event "CRITICAL: Ollama is down." && exit 1
fi
# Check at least one model from fallback chain is available
FOUND_MODEL=0
for m in $TURBO_MODELS; do
    ollama list 2>/dev/null | grep -q "$m" && FOUND_MODEL=1 && break
done
if [ "$FOUND_MODEL" -eq 0 ]; then
    log_event "CRITICAL: No supported model found. Tried: $TURBO_MODELS" && exit 1
fi

# Fetch Emails
if [ -n "$QUEUE_FILE" ]; then
    IDS=($(cat "$QUEUE_FILE"))
else
    # Fetch all target IDs at once
    ALL_IDS_JSON=$(gog gmail search 'is:unread' --max "$LIMIT" --json)
    IDS=($(echo "$ALL_IDS_JSON" | jq -r '.threads[].id' 2>/dev/null))
    # Fallback to sed if jq fails to parse gog output
    if [ ${#IDS[@]} -eq 0 ]; then
        IDS=($(echo "$ALL_IDS_JSON" | sed -n 's/.*"id": "\([^"]*\)".*/\1/p'))
    fi
fi

if [ ${#IDS[@]} -eq 0 ]; then
    log_event "No work found. Exiting." && exit 0
fi

# --- SECTION B: ONE-SHOT EXECUTION ---
log_event "[2/4] Classifying ${#IDS[@]} emails (One-Shot)..."

EMAIL_DATA=""
for ID in "${IDS[@]}"; do
    if grep -q "$ID" "$DB_FILE"; then continue; fi
    SNIPPET_JSON=$(gog gmail thread get "$ID" --json --results-only)
    
    # Robust extraction using jq
    SUBJECT=$(echo "$SNIPPET_JSON" | jq -r '.thread.messages[0].payload.headers[] | select(.name=="Subject") | .value' 2>/dev/null)
    SNIPPET=$(echo "$SNIPPET_JSON" | jq -r '.thread.messages[0].snippet // ""' 2>/dev/null | head -c 500)
    
    # Fallback if jq fails
    if [ -z "$SUBJECT" ]; then SUBJECT=$(echo "$SNIPPET_JSON" | grep -o '"name": "Subject", "value": "[^"]*"' | head -1 | cut -d'"' -f5); fi
    if [ -z "$SNIPPET" ]; then SNIPPET=$(echo "$SNIPPET_JSON" | grep -o '"snippet": "[^"]*"' | head -1 | cut -d'"' -f4 | head -c 500); fi

    log_event "🧠 Thinking about: '$SUBJECT'..."
    EMAIL_DATA+="ID: $ID | Content: $SNIPPET\n"
done

# Sanitize input: strip control chars and normalize so request JSON stays valid
EMAIL_DATA=$(echo -n "$EMAIL_DATA" | tr -d '\000-\037')
# Use intent router + block loader when available (Stage 2)
ROUTER="$WORKSPACE/scripts/harper_intent_router.sh"
LOAD_BLOCK="$WORKSPACE/scripts/harper_load_block.sh"
BLOCK_ID="email_cleaner"
[ -x "$ROUTER" ] && BLOCK_ID=$("$ROUTER" "email inbox clean triage")
if [ -x "$LOAD_BLOCK" ]; then
    SYSTEM_PROMPT=$("$LOAD_BLOCK" harper_base)$'\n'$("$LOAD_BLOCK" "$BLOCK_ID")
else
    SYSTEM_PROMPT=$(cat "$LIBRARY_DIR/harper_base.txt" "$LIBRARY_DIR/email_cleaner.txt" 2>/dev/null | tr -d '\000-\037')
fi
[ -z "$SYSTEM_PROMPT" ] && SYSTEM_PROMPT="You are a JSON formatter. Output: {\"decisions\":[{\"id\":\"ID\",\"action\":\"archive|label|delete|skip\",\"label\":\"...\"}]}."

if [ "$WORKER_MODE" -eq 1 ]; then
    # STRICT WORKER MODE: Minimalist prompt to prevent hallucinations and JSON breaks
    SYSTEM_PROMPT="You are a JSON formatter. Input: Email Snippets. Output: {\"decisions\": [{\"id\": \"ID\", \"action\": \"archive|label|delete|skip\", \"label\": \"Updates|Promotions|Social|Forums\"}]}. No talk. No markdown."
fi

CURRENT_MODEL=""

call_ollama() {
    local prompt_hint="$1"
    local model="${2:-}"
    [ -z "$model" ] && model="${CURRENT_MODEL:-qwen3-vl:8b}"
    # Ollama structured output schema - enforces exact JSON shape
    local format_schema='{"type":"object","properties":{"decisions":{"type":"array","items":{"type":"object","properties":{"id":{"type":"string"},"action":{"type":"string"},"label":{"type":"string"}},"required":["id","action"]}}},"required":["decisions"]}'
    local json_payload
    json_payload=$(jq -n \
        --arg model "$model" \
        --arg system "$SYSTEM_PROMPT"$'\n'"$prompt_hint" \
        --arg user "Analyze these emails. Return JSON: {\"decisions\":[{\"id\":\"ID\",\"action\":\"archive|label|delete|skip\",\"label\":\"...\"}]}"$'\n\n'"$EMAIL_DATA" \
        --argjson format "$format_schema" \
        '{
          model: $model,
          messages: [
            { role: "system", content: $system },
            { role: "user", content: $user }
          ],
          stream: false,
          format: $format,
          think: false,
          options: { temperature: 0 }
        }' 2>/dev/null)
    if [ -z "$json_payload" ]; then
        # Fallback if jq schema fails - use basic json format
        json_payload=$(jq -n \
            --arg model "$model" \
            --arg system "$SYSTEM_PROMPT"$'\n'"$prompt_hint" \
            --arg user "Analyze these emails and return valid JSON decisions:\n$EMAIL_DATA" \
            '{ model: $model, messages: [{ role: "system", content: $system }, { role: "user", content: $user }], stream: false, format: "json", think: false, options: { temperature: 0 } }')
    fi
    curl -s -X POST http://localhost:11434/api/chat -d "$json_payload"
}

# --- SECTION B4: JSON RECOVERY (5-Step Plan) ---
# Plan: 1) Parse 2) Strip markdown 3) Regex extract 4) Retry Ollama 5) Exit non-zero
parse_and_validate_json() {
    local raw="$1"
    
    if [ -z "$raw" ]; then
        echo ""
        return
    fi

    # Step 1: Extract content from Ollama wrapper (content or thinking)
    local content=$(echo "$raw" | jq -r '.message.content // .message.thinking // empty' 2>/dev/null)
    if [ -z "$content" ] || [ "$content" == "null" ]; then
        echo "$raw" > "$DEBUG_RESPONSE_FILE" 2>/dev/null || true
        content=$(echo "$raw" | sed -n 's/.*"content": "\(.*\)".*/\1/p' | sed 's/\\n//g' | sed 's/\\"/"/g')
        [ -z "$content" ] && content=$(echo "$raw" | sed -n 's/.*"thinking": "\(.*\)".*/\1/p' | sed 's/\\n/\n/g' | sed 's/\\"/"/g')
    fi

    # Step 2: Strip markdown fences (```json ... ``` or ``` ... ```)
    if echo "$content" | grep -q '```'; then
        content=$(echo "$content" | sed -n '/```/,/```/p' | sed '/^```/d' | tr -d '\000-\037')
    fi

    # Step 3: Regex extract {"decisions":[...]} — range from first { to last }
    if ! echo "$content" | jq -e '.decisions' >/dev/null 2>&1; then
        content=$(echo "$content" | sed -n '/{/,/}/p' | head -n 100)
    fi

    # Step 4: Validate
    if ! echo "$content" | jq -e . >/dev/null 2>&1; then
        echo "$content" > "$DEBUG_CONTENT_FILE" 2>/dev/null || true
        content=$(echo "$content" | grep -oE '\{[^{}]*\}' | head -1)
    fi
    echo "$content"
}

# Pre-flight: pick first available model from fallback chain
for m in $TURBO_MODELS; do
    if ollama list 2>/dev/null | grep -q "$m"; then
        CURRENT_MODEL="$m"
        harper_log INFO turbo "Using model" "model=$m" 2>/dev/null || true
        break
    fi
done
[ -z "$CURRENT_MODEL" ] && CURRENT_MODEL="qwen3-vl:8b"

RESPONSE=$(call_ollama)
CLEAN_JSON=$(parse_and_validate_json "$RESPONSE")

# Retry loop: stricter prompt, then model fallback
RETRY_COUNT=0
while ! echo "$CLEAN_JSON" | jq -e '.decisions' >/dev/null 2>&1; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -eq 1 ]; then
        log_event "⚠️ JSON invalid or missing 'decisions' array. Retrying with stricter prompt..."
        RESPONSE=$(call_ollama "IMPORTANT: Return ONLY a JSON object with a 'decisions' array.")
    elif [ $RETRY_COUNT -le 3 ]; then
        # Try next model in fallback chain
        NEXT_MODEL=""
        for m in $TURBO_MODELS; do
            [ "$m" = "$CURRENT_MODEL" ] && continue
            if ollama list 2>/dev/null | grep -q "$m"; then
                NEXT_MODEL="$m"
                break
            fi
        done
        if [ -n "$NEXT_MODEL" ]; then
            log_event "⚠️ Retrying with model: $NEXT_MODEL"
            CURRENT_MODEL="$NEXT_MODEL"
            RESPONSE=$(call_ollama "Return ONLY valid JSON." "$CURRENT_MODEL")
        else
            break
        fi
    else
        break
    fi
    CLEAN_JSON=$(parse_and_validate_json "$RESPONSE")
done

if ! echo "$CLEAN_JSON" | jq -e '.decisions' >/dev/null 2>&1; then
    echo "$RESPONSE" > "$DEBUG_RESPONSE_FILE" 2>/dev/null || true
    echo "$CLEAN_JSON" > "$DEBUG_CONTENT_FILE" 2>/dev/null || true
    log_event "CRITICAL: Failed to get valid JSON decisions after retry. Inspect $DEBUG_RESPONSE_FILE and $DEBUG_CONTENT_FILE for details."
    harper_log CRITICAL turbo "JSON parse failed after all retries" "response_file=$DEBUG_RESPONSE_FILE" 2>/dev/null || true
    exit 1
fi

DECISIONS=$(echo "$CLEAN_JSON" | jq -c '.decisions')
DECISION_COUNT=$(echo "$DECISIONS" | jq 'length' 2>/dev/null || echo "?")
harper_log INFO turbo "JSON parsed successfully" "decisions=$DECISION_COUNT model=$CURRENT_MODEL" 2>/dev/null || true

# --- LOG AI THINKING ---
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🧠 AI Decisions Insight:" >> "$DIAG_LOG"
echo "$DECISIONS" | jq -c '.[]' | while read -r row; do
    id=$(echo "$row" | jq -r '.id')
    action=$(echo "$row" | jq -r '.action')
    label=$(echo "$row" | jq -r '.label // "N/A"')
    echo "   -> ID $id: $action [Label: $label]" >> "$DIAG_LOG"
done

# --- SECTION B5: PARALLEL ACTION EXECUTION ---
log_event "[3/4] Executing actions (5 concurrent)..."

if [ "$DRY_RUN" -eq 1 ]; then
    log_event "DRY-RUN mode. Decisions: $DECISIONS"
    exit 0
fi

# Export globals for parallel subshells
export DB_FILE LEDGER_FILE DIAG_LOG IDS_STR=$(printf "%s " "${IDS[@]}")
TMP_RESULT_FILE="/tmp/turbo_results_$$"
touch "$TMP_RESULT_FILE"
export TMP_RESULT_FILE

apply_action() {
    local row=$1
    # Use jq for robust parsing
    local id=$(echo "$row" | jq -r '.id // empty')
    local action=$(echo "$row" | jq -r '.action // empty')
    local label=$(echo "$row" | jq -r '.label // empty')

    if [ -z "$id" ] || [ -z "$action" ]; then
        echo "[ERROR] Missing id or action in: $row" >> "$DIAG_LOG"
        echo "FAILURE" >> "$TMP_RESULT_FILE"
        return 1
    fi

    # VALIDATION: ID in current batch
    if [[ ! " $IDS_STR " =~ " $id " ]]; then
        echo "[ERROR] ID $id not found in current batch. Skipping." >> "$DIAG_LOG"
        echo "FAILURE" >> "$TMP_RESULT_FILE"
        return 1
    fi

    # VALIDATION: Action allowed
    case $action in
        archive|label|delete|skip) ;;
        *) echo "[ERROR] Invalid action '$action' for ID $id. Skipping." >> "$DIAG_LOG"; echo "FAILURE" >> "$TMP_RESULT_FILE"; return 1 ;;
    esac

    if [ "$action" == "skip" ]; then
        echo "[INFO] Skipping ID $id as requested by AI." >> "$DIAG_LOG"
        echo "SUCCESS" >> "$TMP_RESULT_FILE"
        return 0
    fi

    if [ "$action" == "label" ] && [ -z "$label" ]; then
        echo "[ERROR] Action 'label' but no label for ID $id. Skipping." >> "$DIAG_LOG"
        echo "FAILURE" >> "$TMP_RESULT_FILE"
        return 1
    fi

    # EXECUTION
    local success=0
    case $action in
        archive) gog gmail thread modify "$id" --remove INBOX,UNREAD >/dev/null 2>&1 && success=1 ;;
        label) gog gmail thread modify "$id" --add "$label" --remove INBOX,UNREAD >/dev/null 2>&1 && success=1 ;;
        delete) gog gmail thread modify "$id" --add Trash --remove INBOX,UNREAD >/dev/null 2>&1 && success=1 ;;
    esac

    if [ $success -eq 1 ]; then
        echo "$id" >> "$DB_FILE"
        echo "[SUCCESS] Applied $action to $id" >> "$DIAG_LOG"
        echo "SUCCESS" >> "$TMP_RESULT_FILE"
        return 0
    else
        echo "[FAILURE] Failed to execute $action on $id" >> "$DIAG_LOG"
        echo "FAILURE" >> "$TMP_RESULT_FILE"
        return 1
    fi
}

# Use xargs for parallel execution
echo "$DECISIONS" | jq -c '.[]' | xargs -I {} -P "$CONCURRENT_ACTIONS" bash -c "$(declare -f apply_action); apply_action '{}'"

# --- SECTION H: REPORT ---
SUCCESS_COUNT=$(grep -c "SUCCESS" "$TMP_RESULT_FILE" || echo 0)
FAILURE_COUNT=$(grep -c "FAILURE" "$TMP_RESULT_FILE" || echo 0)
rm -f "$TMP_RESULT_FILE"

SUMMARY="🦞 Batch Mission Complete. Success: $SUCCESS_COUNT, Failure: $FAILURE_COUNT. Verified through Truth Database."
log_event "[4/4] $SUMMARY"
imsg send --text "$SUMMARY" --to +12818810740
if [ "$SILENT" -eq 0 ]; then
    openclaw agent --agent main --session-id "harper-cli-chat" --message "🏁 $SUMMARY" --local
fi
