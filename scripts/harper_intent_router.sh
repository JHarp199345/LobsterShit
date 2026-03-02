#!/bin/bash
# Harper Intent Router — Stage 2
# Maps user text to prompt blocks. Fallback: harper_base.txt
# Usage: harper_intent_router.sh "user message"
# Output: block_id (email_cleaner|calendar_sync|imsg_responder|harper_base)

LIB="${HARPER_PROMPT_LIBRARY:-$HOME/.openclaw/prompt_library}"
INPUT="${1:-}"
CACHE_TTL=60
CACHE_FILE="${TMPDIR:-/tmp}/harper_intent_cache_$$"

# Intent keyword map (from plan Section D)
# email_cleaner
EMAIL_KEYWORDS="sort|mail|email|inbox|clean|triage|archive|newsletter|organize|categorize"
# calendar_sync
CALENDAR_KEYWORDS="calendar|schedule|event|meeting|appointment"
# imsg_responder
IMSG_KEYWORDS="text|message|imsg|imessage|reply to"

normalize() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d '\000-\037'
}

TEXT=$(normalize "$INPUT")

# No input -> fallback
[ -z "$TEXT" ] && echo "harper_base" && exit 0

# Match in order of specificity
if echo "$TEXT" | grep -qE "($EMAIL_KEYWORDS)"; then
  [ -f "$LIB/email_cleaner.txt" ] && echo "email_cleaner" && exit 0
fi
if echo "$TEXT" | grep -qE "($CALENDAR_KEYWORDS)"; then
  [ -f "$LIB/calendar_sync.txt" ] && echo "calendar_sync" && exit 0
fi
if echo "$TEXT" | grep -qE "($IMSG_KEYWORDS)"; then
  [ -f "$LIB/imsg_responder.txt" ] && echo "imsg_responder" && exit 0
fi

# Fallback
echo "harper_base"
