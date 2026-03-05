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

# Source model auto-detector (model-agnostic: no hardcoded model names)
[ -f "$WORKSPACE/scripts/lib/ollama_model.sh" ] && source "$WORKSPACE/scripts/lib/ollama_model.sh"

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
    [ -z "$model" ] && model="$CURRENT_MODEL"
    # Ollama structured output schema - enforces exact JSON shape
    local format_schema='{"type":"object","properties":{"decisions":{"type":"array","items":{"type":"object","properties":{"id":{"type":"string"},"action":{"type":"string"},"label":{"type":"string"}},"required":["id","action"]}}},"required":["decisions"]}'
    local user_msg="Analyze these emails. Return ONLY valid JSON with a 'decisions' array.\n\n${EMAIL_DATA}"
    [ -n "$prompt_hint" ] && user_msg="${prompt_hint}\n\n${EMAIL_DATA}"
    local json_payload
    # Use printf | jq --rawfile to safely handle any chars in EMAIL_DATA
    local tmp_data
    tmp_data=$(mktemp)
    printf '%s' "$EMAIL_DATA" > "$tmp_data"
    json_payload=$(jq -n \
        --arg model "$model" \
        --arg system "$SYSTEM_PROMPT" \
        --arg hint "$prompt_hint" \
        --rawfile emails "$tmp_data" \
        --argjson format "$format_schema" \
        '{
          model: $model,
          messages: [
            { role: "system", content: $system },
            { role: "user",   content: ("Analyze these emails. Return ONLY valid JSON with a decisions array.\(if $hint != "" then "\n\n" + $hint else "" end)\n\n" + $emails) }
          ],
          stream: false,
          format: $format,
          think: false,
          options: { temperature: 0, num_ctx: 8192 }
        }' 2>/dev/null)
    rm -f "$tmp_data"
    if [ -z "$json_payload" ]; then
        # Fallback: plain json format, no schema (for older Ollama or models that reject schema)
        tmp_data=$(mktemp)
        printf '%s' "$EMAIL_DATA" > "$tmp_data"
        json_payload=$(jq -n \
            --arg model "$model" \
            --arg system "$SYSTEM_PROMPT" \
            --rawfile emails "$tmp_data" \
            '{ model: $model, messages: [{ role: "system", content: $system }, { role: "user", content: ("Analyze these emails and return valid JSON:\n\n" + $emails) }], stream: false, format: "json", think: false, options: { temperature: 0 } }')
        rm -f "$tmp_data"
    fi
    curl -s --max-time 300 -X POST http://localhost:11434/api/chat -d "$json_payload"
}

# --- SECTION B4: JSON RECOVERY (5-Step Plan) ---
# Handles Qwen3 thinking models: content may be plain JSON, OR wrapped in
# <think>...</think>JSON, OR the thinking is a separate field entirely.
parse_and_validate_json() {
    local raw="$1"

    if [ -z "$raw" ]; then
        echo ""
        return
    fi

    # Save raw for debugging on failure (overwritten on each attempt)
    echo "$raw" > "$DEBUG_RESPONSE_FILE" 2>/dev/null || true

    # Step 1: Extract message.content (primary) or message.thinking (fallback)
    local content
    content=$(echo "$raw" | jq -r '.message.content // empty' 2>/dev/null)

    # Step 1b: If content is empty or null, fall back to thinking field
    if [ -z "$content" ] || [ "$content" = "null" ]; then
        content=$(echo "$raw" | jq -r '.message.thinking // empty' 2>/dev/null)
    fi

    # Step 1c: If jq failed entirely, try sed-based extraction
    if [ -z "$content" ]; then
        content=$(echo "$raw" | sed -n 's/.*"content":[[:space:]]*"\(.*\)".*/\1/p' | \
            sed 's/\\n/\n/g' | sed 's/\\"/"/g' | head -n 200)
    fi

    # Step 2: Strip <think>...</think> blocks (Qwen3 / DeepSeek-R1 thinking output)
    # These appear when think:false isn't respected or model ignores it
    if echo "$content" | grep -q '<think>'; then
        content=$(echo "$content" | sed 's/<think>.*<\/think>//g' | sed 's/<think>.*//g')
    fi

    # Step 3: Strip markdown fences
    if echo "$content" | grep -q '```'; then
        content=$(echo "$content" | sed -n '/```/,/```/p' | sed '/^```/d')
    fi

    # Step 4: If still not valid JSON with .decisions, extract the JSON object
    if ! echo "$content" | jq -e '.decisions' >/dev/null 2>&1; then
        # Try to pull out the outermost {...} that contains "decisions"
        local extracted
        extracted=$(echo "$content" | python3 -c "
import sys, re, json
text = sys.stdin.read()
# Find JSON object containing 'decisions'
for m in re.finditer(r'\{', text):
    start = m.start()
    depth = 0
    for i, c in enumerate(text[start:], start):
        if c == '{': depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                candidate = text[start:i+1]
                try:
                    obj = json.loads(candidate)
                    if 'decisions' in obj:
                        print(candidate)
                        sys.exit(0)
                except: pass
                break
" 2>/dev/null)
        [ -n "$extracted" ] && content="$extracted"
    fi

    # Step 5: Final validation - save content for debug if still broken
    if ! echo "$content" | jq -e '.decisions' >/dev/null 2>&1; then
        echo "$content" > "$DEBUG_CONTENT_FILE" 2>/dev/null || true
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
# If no preferred model found, auto-detect whatever is installed in Ollama
if [ -z "$CURRENT_MODEL" ]; then
    CURRENT_MODEL=$(get_active_model 2>/dev/null)
    [ -n "$CURRENT_MODEL" ] && harper_log INFO turbo "Auto-detected model" "model=$CURRENT_MODEL" 2>/dev/null || true
fi
[ -z "$CURRENT_MODEL" ] && log_event "CRITICAL: No Ollama model found. Install a model with: ollama pull <model>" && exit 1

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
TMP_IMPORTANT_FILE="/tmp/turbo_important_$$"
touch "$TMP_RESULT_FILE" "$TMP_IMPORTANT_FILE"
export TMP_RESULT_FILE TMP_IMPORTANT_FILE

# Build subject lookup for the SMS summary (ID -> Subject)
declare -A SUBJECT_MAP
while IFS='|' read -r entry; do
    entry_id=$(echo "$entry" | sed 's/^ID: //' | cut -d' ' -f1)
    entry_subj=$(echo "$entry" | grep -oP '(?<=Subject: ).*' 2>/dev/null || echo "")
    [ -n "$entry_id" ] && SUBJECT_MAP["$entry_id"]="$entry_subj"
done < <(echo -e "$EMAIL_DATA" | grep "^ID:")
export SUBJECT_MAP_JSON
SUBJECT_MAP_JSON=$(for k in "${!SUBJECT_MAP[@]}"; do echo "$k|${SUBJECT_MAP[$k]}"; done | jq -Rn '[inputs | split("|") | {(.[0]): .[1]}] | add // {}')

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

    # Track INBOX-labeled emails (these are the "important" ones)
    if [ "$action" == "label" ] && [ "$label" == "INBOX" ]; then
        local subj
        subj=$(echo "$SUBJECT_MAP_JSON" | jq -r --arg id "$id" '.[$id] // "ID:\($id)"' 2>/dev/null || echo "ID:$id")
        echo "$subj" >> "$TMP_IMPORTANT_FILE"
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

# Build SMS summary with any important (INBOX-labeled) emails
IMPORTANT_COUNT=$(wc -l < "$TMP_IMPORTANT_FILE" | tr -d ' ')
SUMMARY="🦞 Batch Done. Sorted: $SUCCESS_COUNT, Failed: $FAILURE_COUNT."
if [ "$IMPORTANT_COUNT" -gt 0 ]; then
    IMPORTANT_LIST=$(head -5 "$TMP_IMPORTANT_FILE" | tr '\n' '; ')
    SUMMARY="$SUMMARY Important($IMPORTANT_COUNT): $IMPORTANT_LIST"
fi
rm -f "$TMP_IMPORTANT_FILE"

log_event "[4/4] $SUMMARY"
imsg send --to +12818810740 --text "$SUMMARY"
if [ "$SILENT" -eq 0 ]; then
    openclaw agent --agent main --session-id "harper-cli-chat" --message "🏁 $SUMMARY" --local
fi
