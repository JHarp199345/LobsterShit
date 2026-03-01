# JSON Failure Fix: Comprehensive Bulletproof Plan

## Problem Statement

The turbo engine persistently fails with:
- `⚠️ JSON invalid or missing 'decisions' array. Retrying with stricter prompt...`
- `CRITICAL: Failed to get valid JSON decisions after retry.`

Failures occur within 1–2 seconds of the Ollama call, suggesting the model returns non-conforming output that parsing cannot recover.

---

## Root Cause Analysis

| Hypothesis | Evidence | Likelihood |
|------------|----------|------------|
| **Model returns non-JSON** | qwen3-vl:8b may prefix reasoning, wrap in markdown, or use different structure | High |
| **format: "json" is weak** | Basic JSON mode does not enforce schema; model can still add text | High |
| **Vision model on text-only** | qwen3-vl:8b is VL; text-only input may confuse it | Medium |
| **Bash/jq parsing fragility** | Escaped quotes, newlines, large payloads can break sed/jq | Medium |
| **Empty or truncated response** | Fast failure could mean empty content or timeout | Low |

---

## Solution: Three-Layer Defense

### Layer 1: Ollama Structured Outputs (Schema Enforcement)

**Ollama supports schema-constrained JSON** (Dec 2024+). Use it.

**Current (weak):**
```json
"format": "json"
```

**Bulletproof:**
```json
"format": {
  "type": "object",
  "properties": {
    "decisions": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "action": { "type": "string", "enum": ["archive", "label", "delete", "skip"] },
          "label": { "type": "string" }
        },
        "required": ["id", "action"]
      }
    }
  },
  "required": ["decisions"]
}
```

**Implementation:** Pass this object in the `format` field of the Ollama request. The model is constrained to return exactly this structure.

**Docs:** https://docs.ollama.com/capabilities/structured-outputs

---

### Layer 2: Prompt Grounding + Minimal System Prompt

Ollama docs: *"It is ideal to also pass the JSON schema as a string in the prompt to ground the model's response."*

**Changes:**
1. **Worker mode by default** for batch: Use the minimal "JSON formatter" system prompt (already in script).
2. **Include schema in user message:** Append to the user content:
   ```
   Return JSON: {"decisions":[{"id":"ID","action":"archive|label|delete|skip","label":"..."}]}
   ```
3. **Reduce system prompt size** for batch: Long instructions may dilute the output-format signal.

---

### Layer 3: Model Fallback Chain

If the primary model fails, try alternatives in order:

| Priority | Model | Rationale |
|----------|-------|-----------|
| 1 | `qwen3:8b` (text-only) | Better for text classification than VL |
| 2 | `qwen3-vl:8b` (current) | Keep as fallback |
| 3 | `qwen2.5:8b` | Older, often more stable |
| 4 | `llama3.2:3b` | Small, fast, good at JSON |

**Implementation:** Pre-flight checks which models exist. On JSON failure, retry with next model in chain (max 2 retries with different models).

---

## Implementation Plan

### Phase A: Structured Outputs (Primary Fix)

**File:** `scripts/turbo_cleaner_v3.sh`

1. **Replace `format: "json"`** with the schema object in `call_ollama`.
2. **Build schema via jq** (avoids escaping issues):
   ```bash
   FORMAT_SCHEMA='{"type":"object","properties":{"decisions":{"type":"array","items":{"type":"object","properties":{"id":{"type":"string"},"action":{"type":"string"},"label":{"type":"string"}},"required":["id","action"]}}},"required":["decisions"]}'
   ```
3. **Pass in jq payload:** `format: ($FORMAT_SCHEMA | fromjson)` or equivalent.

**File:** `scripts/turbo_ollama_helper.js` (NEW – optional but recommended)

A small Node.js script that:
- Accepts prompt + email data via stdin or args
- Calls Ollama with schema
- Returns parsed `decisions` array or exits non-zero
- Writes raw response to `$WORKSPACE/turbo_last_response.json` on failure for debugging

**Why Node:** Native `JSON.parse`, no jq/sed edge cases, easier to add retry logic and model fallback.

---

### Phase B: Debug Capture (Immediate Value)

**On any JSON parse failure:**
1. Write raw Ollama response to `$WORKSPACE/turbo_debug_last_response.json`
2. Write extracted content to `$WORKSPACE/turbo_debug_last_content.txt`
3. Log paths in the CRITICAL message: `"Inspect turbo_debug_last_response.json for details"`

This enables post-mortem without re-running.

---

### Phase C: Model Fallback

1. **Pre-flight:** Build list of available models: `ollama list | awk '{print $1}'`
2. **Config:** `TURBO_MODELS="qwen3:8b qwen3-vl:8b qwen2.5:8b"` (or from env)
3. **Retry loop:** On parse failure, try next model (max 2 retries total).

---

### Phase D: Nuclear Option – One-Shot Fallback

If all retries fail:
1. **Fallback mode:** Process emails one-at-a-time with a simpler prompt (single decision per call).
2. **Slower but reliable:** 20 emails = 20 calls instead of 1, but each call returns a single `{"id":"x","action":"y"}` which is trivial to parse.
3. **Flag:** `--fallback-single` or auto-enable when batch fails twice.

---

## File Changes Summary

| File | Action |
|------|--------|
| `scripts/turbo_cleaner_v3.sh` | Add schema to format, debug capture, model fallback |
| `scripts/turbo_ollama_helper.js` | NEW: Node helper for robust Ollama + JSON (optional) |
| `plan.md` | Update Section B with schema format |

---

## Verification Steps

1. **Dry-run with 1 email:** `turbo_cleaner_v3.sh --dry-run --limit 1`
2. **Inspect debug files** if it fails
3. **Test schema:** Manually curl Ollama with schema, verify response shape
4. **Test model fallback:** Temporarily use invalid model name, confirm fallback triggers

---

## Is This Possible?

**Yes.** The fix is well within reach:

1. **Ollama structured outputs** are documented and supported.
2. **Schema enforcement** is the standard solution for reliable JSON from LLMs.
3. **Model fallback** and **debug capture** are straightforward.
4. **One-at-a-time fallback** guarantees eventual success.

The main risk is **Ollama version** – structured outputs with schema require a recent Ollama (late 2024+). If the user's Ollama is older, Phase A may not work until they update. In that case, Phase B (debug capture) + Phase D (single-email fallback) still provide a path to reliability.

---

## Recommended Order

1. **Phase B first** (debug capture) – 10 min, immediate visibility into failures
2. **Phase A** (structured outputs) – 30 min, addresses root cause
3. **Phase C** (model fallback) – 20 min, resilience
4. **Phase D** (single fallback) – 30 min, last-resort reliability

**Total estimate:** ~2 hours for full bulletproofing.

---

# Comprehensive Logging Plan

## Problem

Logging is ad-hoc across Harper operations:
- `turbo_diagnostic.log` receives mixed events from turbo, architect, command center
- No standardized format, levels, or component tags
- `daily_ledger.log` is underused
- Interactive chat, prompt splicer, and Gmail operations have no logging
- No way to trace a full operation end-to-end or test that logging works

---

## Logging Architecture

### 1. Unified Log Format

Every log entry follows:
```
[TIMESTAMP] [LEVEL] [COMPONENT] message [| key=value ...]
```

**Example:**
```
[2026-02-28 23:15:42] [INFO] [turbo] Pre-flight complete. Ollama=ok model=qwen3-vl:8b
[2026-02-28 23:15:43] [DEBUG] [turbo] Ollama request: 2 emails, prompt_len=1200
[2026-02-28 23:15:48] [INFO] [turbo] JSON parsed. decisions=2 valid=2
[2026-02-28 23:15:49] [ERROR] [turbo] Action failed | id=abc123 action=label err="label not found"
```

**Levels:** `DEBUG` | `INFO` | `WARN` | `ERROR` | `CRITICAL`

**Components:** `turbo` | `architect` | `command_center` | `chat` | `monitor` | `splicer` | `gmail` | `ollama`

---

### 2. Shared Logger Script

**File:** `scripts/lib/logger.sh`

```bash
# Source from any script: source "$WORKSPACE/scripts/lib/logger.sh"
# Usage: harper_log INFO turbo "Pre-flight complete"
#        harper_log DEBUG turbo "Request payload" "payload=$PAYLOAD"

HARPER_LOG_LEVEL="${HARPER_LOG_LEVEL:-INFO}"  # DEBUG|INFO|WARN|ERROR|CRITICAL
HARPER_LOG_FILE="${HARPER_LOG_FILE:-$WORKSPACE/harper_operations.log}"

harper_log() {
    local level="$1" component="$2" msg="$3" extra="${4:-}"
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    local line="[$ts] [$level] [$component] $msg"
    [ -n "$extra" ] && line="$line | $extra"
    echo "$line" >> "$HARPER_LOG_FILE"
    # Also append to legacy DIAG_LOG for backward compatibility with monitor
    [ -n "$DIAG_LOG" ] && echo "$line" >> "$DIAG_LOG"
}
```

**Level filtering:** If `HARPER_LOG_LEVEL=INFO`, suppress DEBUG. Level order: DEBUG < INFO < WARN < ERROR < CRITICAL. Only log if entry level >= configured level.

---

### 3. Components to Instrument

| Component | File | Log Points |
|-----------|------|------------|
| **Turbo** | `turbo_cleaner_v3.sh` | Pre-flight (each check), Ollama request (DEBUG: payload size), JSON parse (success/fail), each action (success/fail), summary |
| **Architect** | `task_architect.sh` | Init, state load/save, batch start/end, approval flow |
| **Command Center** | `command_center.sh` | Menu display, each option selected, gateway start, context change |
| **Chat** | `interactive_chat.sh` | Session start, each message sent, session end |
| **Monitor** | `monitor.sh` | Poll/refresh (optional, can be noisy) |
| **Prompt Splicer** | OpenClaw core | Block load, intent match, prepend size (requires core change) |
| **Gmail** | Via turbo | gog calls: search result count, thread fetch (DEBUG) |

---

### 4. Log Destinations

| File | Purpose |
|------|---------|
| `harper_operations.log` | Primary unified log (all components) |
| `turbo_diagnostic.log` | Legacy; keep appending for monitor compatibility |
| `turbo_debug_last_response.json` | Raw Ollama response on JSON failure |
| `daily_ledger.log` | Human-readable action summary (e.g. "Archived 5, Labeled 3") |

---

### 5. Log Rotation

Prevent unbounded growth:

```bash
# In logger or a daily cron
# Rotate when harper_operations.log > 10MB
if [ -f "$HARPER_LOG_FILE" ] && [ $(stat -f%z "$HARPER_LOG_FILE" 2>/dev/null || stat -c%s "$HARPER_LOG_FILE") -gt 10485760 ]; then
    mv "$HARPER_LOG_FILE" "$HARPER_LOG_FILE.1"
    touch "$HARPER_LOG_FILE"
fi
```

Or use `logrotate` if available.

---

### 6. Testing Logging

**Verification script:** `scripts/test_logging.sh`

```bash
# 1. Source logger
# 2. Emit one entry per level (DEBUG, INFO, WARN, ERROR, CRITICAL)
# 3. Emit one entry per component (turbo, architect, etc.)
# 4. Assert harper_operations.log contains expected lines
# 5. Run turbo --dry-run --limit 1, assert log has turbo entries
# 6. Run command center option 7 (exit), assert log has command_center entry
```

**Manual test:**
```bash
source scripts/lib/logger.sh
harper_log INFO turbo "Test message"
grep "Test message" harper_operations.log && echo "PASS"
```

---

### 7. Implementation Order

| Phase | Task | Est. |
|-------|------|------|
| L1 | Create `scripts/lib/logger.sh` with level filtering | 15 min |
| L2 | Integrate logger into `turbo_cleaner_v3.sh` (replace log_event) | 20 min |
| L3 | Integrate logger into `task_architect.sh` | 15 min |
| L4 | Integrate logger into `command_center.sh` | 15 min |
| L5 | Integrate logger into `interactive_chat.sh` | 10 min |
| L6 | Add log rotation (or document manual rotation) | 10 min |
| L7 | Create `scripts/test_logging.sh` | 20 min |

**Total:** ~2 hours for full logging rollout.

---

### 8. OpenClaw / Prompt Splicer Logging

The Harper prompt splicer lives in `openclaw-core/dist/subagent-registry-CVXe4Cfs.js`. To log there:

- Use `log$4.debug()` or `log$4.info()` (existing logger in that bundle)
- Add: `log$4.info("Harper Splicer", { blocksLoaded: ["harper_base","email_cleaner"], prependChars: harperPrepend.length })`
- This requires editing the bundled JS; tag with `// HARPER-OPTIMIZATION`

**Alternative:** Log to a file from the plugin if a file path is configurable. Otherwise, rely on OpenClaw's built-in logging and ensure Harper events are distinguishable (e.g. prefixed with `[Harper]`).

---

### 9. File Summary

| File | Action |
|------|--------|
| `scripts/lib/logger.sh` | NEW: Shared logger |
| `scripts/turbo_cleaner_v3.sh` | Use harper_log instead of log_event |
| `scripts/task_architect.sh` | Use harper_log instead of log_worker |
| `scripts/command_center.sh` | Add harper_log at key points |
| `scripts/interactive_chat.sh` | Add harper_log for session/message |
| `scripts/test_logging.sh` | NEW: Verification script |
| `workorders.md` | Add mission for logging |

---

## Combined Execution Order (JSON Fix + Logging)

| Step | Phase | Task |
|------|-------|------|
| 1 | L1 | Create `scripts/lib/logger.sh` |
| 2 | B | Add debug capture to turbo (write raw response on failure) |
| 3 | L2 | Integrate logger into turbo |
| 4 | A | Add Ollama structured outputs (schema) to turbo |
| 5 | L7 | Create `scripts/test_logging.sh` |
| 6 | L3–L5 | Integrate logger into architect, command_center, chat |
| 7 | C | Add model fallback chain |
| 8 | L6 | Add log rotation |
| 9 | D | Add single-email fallback (if needed) |

**Rationale:** Logging first gives visibility into the JSON failures. Debug capture + schema fix address the root cause. Test script validates logging. Remaining phases add resilience.
