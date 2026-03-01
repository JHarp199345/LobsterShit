#!/bin/bash
# 🦞 HARPER UNIFIED LOGGER
# Source from any script: source "$WORKSPACE/scripts/lib/logger.sh"
# Usage: harper_log INFO turbo "Pre-flight complete"
#        harper_log DEBUG turbo "Request payload" "payload_len=1200"

WORKSPACE="${WORKSPACE:-/Users/jesseharper/Documents/Workshop/workhorse}"
HARPER_LOG_LEVEL="${HARPER_LOG_LEVEL:-INFO}"  # DEBUG|INFO|WARN|ERROR|CRITICAL
HARPER_LOG_FILE="${HARPER_LOG_FILE:-$WORKSPACE/harper_operations.log}"
DIAG_LOG="${DIAG_LOG:-$WORKSPACE/turbo_diagnostic.log}"

# Level numeric order for filtering (higher = more severe)
_level_num() {
    case "$1" in
        DEBUG)   echo 0 ;;
        INFO)    echo 1 ;;
        WARN)    echo 2 ;;
        ERROR)   echo 3 ;;
        CRITICAL) echo 4 ;;
        *)       echo 1 ;;
    esac
}

harper_log() {
    local level="$1" component="$2" msg="$3" extra="${4:-}"
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    local configured=$( _level_num "$HARPER_LOG_LEVEL" )
    local entry_level=$( _level_num "$level" )
    # Only log if entry level >= configured level
    if [ "$entry_level" -lt "$configured" ]; then
        return 0
    fi
    local line="[$ts] [$level] [$component] $msg"
    [ -n "$extra" ] && line="$line | $extra"
    touch "$HARPER_LOG_FILE" 2>/dev/null || true
    echo "$line" >> "$HARPER_LOG_FILE"
    # Also append to legacy DIAG_LOG for monitor compatibility
    if [ -n "$DIAG_LOG" ]; then
        touch "$DIAG_LOG" 2>/dev/null || true
        echo "$line" >> "$DIAG_LOG"
    fi
}

# Legacy-compatible: log_event for turbo (also echoes to stdout)
log_event() {
    harper_log INFO turbo "$1"
    echo "📡 $1"
}

# Log rotation: rotate when > 10MB (call periodically or at startup)
harper_log_rotate() {
    local max_bytes=10485760
    local size=0
    [ -f "$HARPER_LOG_FILE" ] && size=$(stat -f%z "$HARPER_LOG_FILE" 2>/dev/null || stat -c%s "$HARPER_LOG_FILE" 2>/dev/null || echo 0)
    if [ "$size" -gt "$max_bytes" ] 2>/dev/null; then
        mv "$HARPER_LOG_FILE" "$HARPER_LOG_FILE.1" 2>/dev/null || true
        touch "$HARPER_LOG_FILE" 2>/dev/null || true
    fi
}
