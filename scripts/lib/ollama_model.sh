#!/bin/bash
# 🦞 Ollama Model Auto-Detector
# Sources this file then call get_active_model
# Returns the first available model from Ollama — no hardcoding required.
# Priority: TURBO_MODELS env list → any installed model → empty string (caller handles failure)

get_active_model() {
    local preferred="${TURBO_MODELS:-}"

    # Try preferred list first (caller can override via env)
    if [ -n "$preferred" ]; then
        for m in $preferred; do
            if ollama list 2>/dev/null | awk 'NR>1{print $1}' | grep -qxF "$m"; then
                echo "$m"
                return 0
            fi
        done
    fi

    # Fall back to first model reported by Ollama API
    local first
    first=$(curl -sf --connect-timeout 3 --max-time 5 http://127.0.0.1:11434/api/tags \
        | jq -r '.models[0].name // empty' 2>/dev/null)
    if [ -n "$first" ]; then
        echo "$first"
        return 0
    fi

    # Last resort: parse `ollama list` output directly
    first=$(ollama list 2>/dev/null | awk 'NR>1 && $1!="" {print $1; exit}')
    if [ -n "$first" ]; then
        echo "$first"
        return 0
    fi

    echo ""
    return 1
}
