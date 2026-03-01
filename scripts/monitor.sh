#!/bin/bash
# 🦞 HARPER PULSE MONITOR v1.1
# Mission: Tap into and monitor ALL running AI and System activities.
# MULTI-TERMINAL SAFE: Run this in any terminal to see shared state.

WORKSPACE="/Users/jesseharper/Documents/Workshop/workhorse"
DIAG_LOG="$WORKSPACE/turbo_diagnostic.log"
SESSION_DIR="/Users/jesseharper/.openclaw/agents/main/sessions"

clear
echo "===================================================="
echo "       🦞 HARPER PULSE MONITOR - LIVE 🦞"
echo "===================================================="
echo " [SHARED VIEW] Passive monitoring of all threads."
echo " Safe to keep open while chatting in another tab."
echo "----------------------------------------------------"

# Function to get latest session log
get_latest_session() {
    ls -t "$SESSION_DIR"/*.jsonl 2>/dev/null | head -1
}

# Function to display system health
show_health() {
    GATEWAY="🔴"
    # Shared Instance Detection
    ps -axo args | grep -v grep | grep -q "openclaw-gateway" && GATEWAY="🟢"
    
    OLLAMA="🔴"
    pgrep -x "Ollama" >/dev/null && OLLAMA="🟢"
    
    AGENT="🔴"
    # Agent detection: Green if either an active agent process or a running gateway is detected.
    if ps -axo args | grep -v grep | grep -E -q "openclaw-agent|openclaw agent"; then
        AGENT="🟢 ACTIVE"
    elif ps -axo args | grep -v grep | grep -q "openclaw-gateway"; then
        AGENT="🟢 READY"
    fi
    
    # Check for active mission manifest
    MISSION_STATUS="💤 IDLE"
    STATE_FILE="$WORKSPACE/mission_state.json"
    if [ -f "$STATE_FILE" ]; then
        STATUS=$(jq -r '.status' "$STATE_FILE" 2>/dev/null)
        APPROVED=$(jq -r '.approved' "$STATE_FILE" 2>/dev/null)
        if [[ "$STATUS" == "In-Progress" ]]; then
            PROCESSED=$(jq -r '.processed_count' "$STATE_FILE" 2>/dev/null)
            TOTAL=$(jq -r '.total_items' "$STATE_FILE" 2>/dev/null)
            REMAINING=$(jq -r '.remaining_ids | length' "$STATE_FILE" 2>/dev/null)
            
            APP_SYMBOL="🔒 PENDING"
            [[ "$APPROVED" == "true" ]] && APP_SYMBOL="🔓 APPROVED"
            
            MISSION_STATUS="🔥 ACTIVE ($PROCESSED/$TOTAL emails | $REMAINING left) | $APP_SYMBOL"
        fi
    fi
    
    echo " [SYSTEM] Gateway: $GATEWAY | Ollama: $OLLAMA | Agent: $AGENT"
    echo " [MISSION] Status: $MISSION_STATUS"
}

while true; do
    show_health
    LATEST_SESSION=$(get_latest_session)
    
    echo "----------------------------------------------------"
    echo " [TURBO ENGINE PULSE]"
    tail -n 5 "$DIAG_LOG" | sed 's/^/  /'
    
    if [ -n "$LATEST_SESSION" ]; then
        echo "----------------------------------------------------"
        echo " [LATEST AGENT ACTIVITY - $(basename "$LATEST_SESSION")]"
        # Extract the last message content from the JSONL
        # Shows both user and assistant activity if possible
        tail -n 10 "$LATEST_SESSION" | grep -o '"content":\[{[^]]*}\]' | sed 's/\\"/"/g' | tail -2 | cut -c1-120 | sed 's/^/  /'
    fi
    
    echo "----------------------------------------------------"
    echo " (Type 'exit' to return to menu, or Ctrl+C)"
    
    # Read input with a timeout to allow live updates
    read -t 1 -p " PULSE> " user_input
    
    if [[ "$user_input" == "exit" ]]; then
        echo "Exiting monitor..."
        break
    fi
    
    clear
    echo "===================================================="
    echo "       🦞 HARPER PULSE MONITOR - LIVE 🦞"
    echo "===================================================="
done
