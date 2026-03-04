#!/bin/bash
# 🦞 HARPER COMMAND CENTER v2.0
# Single-instance only: kills any existing OpenClaw on startup.
# No persistence: gateway runs per session, never auto-starts.

WORKSPACE="/Users/jesseharper/Documents/Workshop/workhorse"
ARCHITECT="$WORKSPACE/scripts/task_architect.sh"
TRIAGE="$WORKSPACE/scripts/harper_email_triage.sh"
MONITOR="$WORKSPACE/scripts/monitor.sh"
FULL_RESET="$WORKSPACE/scripts/full_reset.sh"
UNINSTALL_PERSISTENCE="$WORKSPACE/scripts/uninstall_persistence.sh"
GATEWAY_PORT=18789
LEDGER="$WORKSPACE/daily_ledger.log"
DIAG_LOG="$WORKSPACE/turbo_diagnostic.log"

# Source unified logger + rotate if needed
[ -f "$WORKSPACE/scripts/lib/logger.sh" ] && source "$WORKSPACE/scripts/lib/logger.sh"
[ -f "$WORKSPACE/scripts/lib/ollama_model.sh" ] && source "$WORKSPACE/scripts/lib/ollama_model.sh"
[ -n "$(type -t harper_log_rotate 2>/dev/null)" ] && harper_log_rotate
_cc_log() { [ -n "$(type -t harper_log 2>/dev/null)" ] && harper_log INFO command_center "$1" || echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$DIAG_LOG"; }

chmod +x "$ARCHITECT" "$TRIAGE" "$MONITOR" "$FULL_RESET" "$UNINSTALL_PERSISTENCE" "$UNINSTALL_PERSISTENCE"

# 🛑 SINGLE-INSTANCE: Kill any existing OpenClaw on every startup
"$FULL_RESET"

# 🚀 WARM-UP: Start gateway + pre-load model so first response is faster
start_gateway_if_needed &
# Pre-load model — auto-detect active Ollama model (no hardcoding)
(
    if ollama_reachable; then
        WARMUP_MODEL=$(get_active_model 2>/dev/null)
        if [ -n "$WARMUP_MODEL" ]; then
            ollama run "$WARMUP_MODEL" "hi" >/dev/null 2>&1
        fi
    fi
) &

# 🧼 STARTUP CLEANUP: Clear stale locks/PIDs
rm -f /Users/jesseharper/.openclaw/agents/main/sessions/*.lock
rm -f /Users/jesseharper/.openclaw/agents/main/sessions/*.pid 2>/dev/null
rm -f /tmp/openclaw*.pid /tmp/openclaw*.lock 2>/dev/null
rm -f /tmp/mission_batch_*.queue /tmp/turbo_results_* 2>/dev/null
rm -f /Users/jesseharper/.openclaw/exec-approvals.sock 2>/dev/null
rm -f "$WORKSPACE"/*.pid 2>/dev/null

# Helper: is gateway listening on port?
gateway_listening() {
    nc -z 127.0.0.1 "$GATEWAY_PORT" 2>/dev/null || lsof -i ":$GATEWAY_PORT" -sTCP:LISTEN -t 2>/dev/null | grep -q .
}

# Helper: can we actually reach Ollama? (connection check, not just process)
ollama_reachable() {
    curl -sf --connect-timeout 5 --max-time 10 http://127.0.0.1:11434/api/tags >/dev/null 2>&1
}

# Helper: start gateway in background, wait for port
start_gateway_if_needed() {
    if gateway_listening; then return 0; fi
    echo "Starting gateway..."
    mkdir -p /Users/jesseharper/.openclaw/logs
    nohup openclaw gateway run > /Users/jesseharper/.openclaw/logs/gateway.log 2>&1 &
    for i in $(seq 1 15); do
        sleep 1
        gateway_listening && return 0
    done
    echo "Warning: Gateway may still be starting. Proceeding..."
}

# Direct access flags
if [[ "$1" == "--monitor" || "$1" == "-m" ]]; then
    $MONITOR
    exit 0
fi

show_menu() {
    clear
    # Task Coordination & Health Check
    GATEWAY_STATUS="🔴 STOPPED"
    gateway_listening && GATEWAY_STATUS="🟢 ACTIVE"
    
    OLLAMA_STATUS="🔴 UNREACHABLE"
    ollama_reachable && OLLAMA_STATUS="🟢 READY"
    
    TASK_STATUS="💤 IDLE"
    # Check Manifest first for Persistent Worker State
    STATE_FILE="$WORKSPACE/mission_state.json"
    if [ -f "$STATE_FILE" ]; then
        INTERNAL_STATUS=$(jq -r '.status' "$STATE_FILE" 2>/dev/null)
        APPROVED=$(jq -r '.approved' "$STATE_FILE" 2>/dev/null)
        if [[ "$INTERNAL_STATUS" == "In-Progress" ]]; then
            if [[ "$APPROVED" == "true" ]]; then
                TASK_STATUS="🔄 AGENTIC BATCHING"
            else
                TASK_STATUS="🔒 PENDING APPROVAL"
            fi
        fi
    fi

    # Overlay with active process detection
    if ps -axo args | grep -v grep | grep -q "task_architect.sh"; then
        TASK_STATUS="⚡ ARCHITECT ACTIVE"
    elif ps -axo args | grep -v grep | grep -q "turbo_cleaner_v3.sh"; then
        TASK_STATUS="🔥 PROCESSING BATCH"
    fi

    # Get current context setting
    CURRENT_CTX=$(grep '"contextTokens":' /Users/jesseharper/.openclaw/openclaw.json | sed 's/[^0-9]//g')

    echo "===================================================="
    echo "       🦞 HARPER COMMAND CENTER - v2.0 🦞"
    echo "===================================================="
    echo " [SYSTEM HEALTH]"
    echo "  Gateway: $GATEWAY_STATUS"
    echo "  Ollama:  $OLLAMA_STATUS"
    echo "  Task:    $TASK_STATUS"
    echo "  Context: ${CURRENT_CTX:-Default}"
    echo "----------------------------------------------------"
    echo " [MULTI-TAB STATUS]"
    echo "  Instance: Terminal Hook #$PPID"
    echo "  Safety:   Passive Monitoring Enabled"
    echo "----------------------------------------------------"
    echo " [1] 🏗️ EMAIL TRIAGE (CLI Form: batches + approve)"
    echo " [2] 📝 VIEW DAILY LEDGER (Archive History)"
    echo " [3] 🔭 WATCH LIVE DIAGNOSTICS (Pulse)"
    echo " [4] 💬 CHAT (gateway + tools + approvals)"
    echo " [4b] 👁️ APPROVAL WATCHER (run [4] first, then 4b in split pane)"
    echo " [4c] 📱 SMS LISTENER (background — directives via self-text)"
    echo " [5] ⚙️ TUNE M1 (Context Slider)"
    echo " [6] 🛑 FULL RESET (Kill all + clear locks — use when stuck or 'session file locked')"
    echo " [8] 🔌 UNINSTALL PERSISTENCE (remove launchd, run once)"
    echo " [7] 🚪 EXIT"
    echo "===================================================="
    printf " MISSION SELECT: "
}

while true; do
    show_menu
    read choice
    case $choice in
        1)
            # CLI-first: Interactive form (total, batches, approve-all) → runs triage
            $TRIAGE
            echo ""
            echo -n "Press Enter to return to menu..."
            read
            ;;
        2)
            echo "📝 Opening Ledger (Last 20 entries):"
            tail -n 20 "$LEDGER"
            echo "----------------------------------------------------"
            echo -n "Press Enter to return to menu..."
            read
            ;;
        3)
            echo "🔭 Monitoring live pulse (Press Ctrl+C to stop watching):"
            $MONITOR
            ;;
        4)
            if ! ollama_reachable; then
                echo "❌ Ollama unreachable. curl http://127.0.0.1:11434/api/tags failed."
                echo "   Fix: Start Ollama, check port 11434, or run: ollama serve"
                echo ""
                echo -n "Press Enter to return to menu..."
                read
                continue
            fi
            start_gateway_if_needed
            openclaw tui --thinking off --session harper-cli-chat
            ;;
        4b)
            # Approval watcher: run in split pane to approve exec requests from CLI
            "$WORKSPACE/scripts/approval_watcher.sh"
            ;;
        4c)
            # SMS directive listener: background process — text yourself to issue commands
            _cc_log "Starting SMS directive listener in background"
            nohup "$WORKSPACE/scripts/imsg_directive_listener.sh" >> "$DIAG_LOG" 2>&1 &
            echo "📱 SMS Listener started (PID $!). Text yourself to issue directives."
            echo "   Examples: 'sort top 50 emails'  |  'status'  |  'stop'"
            echo ""
            echo -n "Press Enter to return to menu..."
            read
            ;;
        5)
            echo "⚙️ M1 TUNING - Select Context Window:"
            echo " [1] 🏎️ 8k (Maximum Speed)"
            echo " [2] ⚖️ 12k (Recommended)"
            echo " [3] 🧠 24k (Maximum Memory)"
            printf " CHOICE: "
            read ctx_choice
            case $ctx_choice in
                1) NEW_CTX=8192 ;;
                2) NEW_CTX=12288 ;;
                3) NEW_CTX=24576 ;;
                *) NEW_CTX=12288 ;;
            esac
            # Map choice index to value manually since we can't use $ctx_choice in the above block easily without re-reading
            if [ "$ctx_choice" == "1" ]; then NEW_CTX=8192; 
            elif [ "$ctx_choice" == "2" ]; then NEW_CTX=12288;
            elif [ "$ctx_choice" == "3" ]; then NEW_CTX=24576;
            else NEW_CTX=12288; fi
            
            _cc_log "Context slider" "new_ctx=$NEW_CTX"
            echo "Updating context to $NEW_CTX..."
            sed -i '' "s/\"contextTokens\": [0-9]*/\"contextTokens\": $NEW_CTX/" /Users/jesseharper/.openclaw/openclaw.json
            echo "Applying settings... Gateway restart required for full effect."
            sleep 2
            ;;
        6)
            _cc_log "Full reset requested"
            "$FULL_RESET"
            echo ""
            echo -n "Press Enter to return to menu..."
            read
            ;;
        8)
            _cc_log "Uninstall persistence requested"
            "$UNINSTALL_PERSISTENCE"
            echo ""
            echo -n "Press Enter to return to menu..."
            read
            ;;
        7)
            _cc_log "User exit"
            echo "Goodbye, Jesse."
            exit 0
            ;;
        *)
            echo "Invalid selection."
            sleep 1
            ;;
    esac
done
