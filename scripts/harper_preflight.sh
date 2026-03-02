#!/bin/bash
# Harper Pre-flight Checks — Stage 1
# Run before Mission 041 (One-Shot Batch). Exits non-zero if any check fails.

set -e
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
MODEL="${OLLAMA_MODEL:-qwen3-vl:8b}"
PROMPT_LIB="${HARPER_PROMPT_LIBRARY:-$HOME/.openclaw/prompt_library}"

echo "═══ Harper Pre-flight ═══"

# 1. Ollama reachable
if ! curl -sf "$OLLAMA_URL/api/tags" >/dev/null 2>&1; then
  echo "✗ Ollama not reachable at $OLLAMA_URL. Start with: ollama serve"
  exit 1
fi
echo "✓ Ollama OK"

# 2. Model present
if ! curl -sf "$OLLAMA_URL/api/tags" | grep -q "\"name\":\"$MODEL\"" 2>/dev/null; then
  echo "✗ Model $MODEL not found. Run: ollama pull $MODEL"
  exit 1
fi
echo "✓ Model $MODEL OK"

# 3. Prompt library exists (warn only)
if [ ! -d "$PROMPT_LIB" ]; then
  echo "⚠ Prompt library not found at $PROMPT_LIB"
  echo "  Copy from: $(dirname "$0")/prompt_library/ to $PROMPT_LIB"
  echo "  Or set HARPER_PROMPT_LIBRARY"
else
  echo "✓ Prompt library OK ($PROMPT_LIB)"
fi

# 4. Gmail: check for gcloud/gmail CLI (optional; Mission 041 may use different auth)
if command -v gcloud >/dev/null 2>&1; then
  echo "✓ gcloud CLI present"
else
  echo "⚠ gcloud not in PATH (optional for Gmail OAuth)"
fi

echo ""
echo "Pre-flight complete. Ready for batch."
