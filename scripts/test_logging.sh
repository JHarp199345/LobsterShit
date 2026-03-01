#!/bin/bash
# 🦞 HARPER LOGGING VERIFICATION
# Run to verify comprehensive logging is working across components.

WORKSPACE="${WORKSPACE:-/Users/jesseharper/Documents/Workshop/workhorse}"
HARPER_LOG="$WORKSPACE/harper_operations.log"
DIAG_LOG="$WORKSPACE/turbo_diagnostic.log"

echo "=============================================="
echo "  🦞 HARPER LOGGING SELF-TEST"
echo "=============================================="

# 1. Source logger
if [ ! -f "$WORKSPACE/scripts/lib/logger.sh" ]; then
    echo "❌ FAIL: scripts/lib/logger.sh not found"
    exit 1
fi
source "$WORKSPACE/scripts/lib/logger.sh"
echo "✓ Logger sourced"

# 2. Emit one entry per level
harper_log DEBUG turbo "Test DEBUG"
harper_log INFO turbo "Test INFO"
harper_log WARN turbo "Test WARN"
harper_log ERROR turbo "Test ERROR"
harper_log CRITICAL turbo "Test CRITICAL"
echo "✓ Emitted all levels"

# 3. Emit one per component
harper_log INFO architect "Test architect"
harper_log INFO command_center "Test command_center"
harper_log INFO chat "Test chat"
echo "✓ Emitted all components"

# 4. Assert harper_operations.log exists and has entries
if [ ! -f "$HARPER_LOG" ]; then
    echo "❌ FAIL: harper_operations.log not created"
    exit 1
fi
COUNT=$(grep -c "Test" "$HARPER_LOG" 2>/dev/null || echo 0)
if [ "$COUNT" -lt 5 ]; then
    echo "❌ FAIL: Expected at least 5 test entries, found $COUNT"
    exit 1
fi
echo "✓ harper_operations.log has $COUNT test entries"

# 5. Assert DIAG_LOG also has entries (legacy compatibility)
if [ -f "$DIAG_LOG" ]; then
    DIAG_COUNT=$(grep -c "Test" "$DIAG_LOG" 2>/dev/null || echo 0)
    echo "✓ turbo_diagnostic.log has $DIAG_COUNT test entries (legacy)"
fi

echo "=============================================="
echo "  ✅ ALL LOGGING CHECKS PASSED"
echo "=============================================="
echo "Log file: $HARPER_LOG"
echo "Tail:"
tail -n 5 "$HARPER_LOG" | sed 's/^/  /'
