#!/bin/bash
# Harper Load Block — Stage 2
# Loads prompt block content by block_id. Used by intent router + turbo.
# Usage: harper_load_block.sh <block_id>
# Output: block content (stdout)

LIB="${HARPER_PROMPT_LIBRARY:-$HOME/.openclaw/prompt_library}"
BLOCK_ID="${1:-harper_base}"
BLOCK_FILE="$LIB/${BLOCK_ID}.txt"

if [ -f "$BLOCK_FILE" ]; then
  cat "$BLOCK_FILE" | tr -d '\000-\037'
else
  # Fallback: harper_base
  if [ "$BLOCK_ID" != "harper_base" ] && [ -f "$LIB/harper_base.txt" ]; then
    cat "$LIB/harper_base.txt" | tr -d '\000-\037'
  fi
fi
