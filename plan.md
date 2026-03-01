# [ARCHIVED] Previous Phase 3 Drafts (NOT IMPLEMENTED)

<details>
<summary>View Archived Drafts</summary>

## [ARCHIVED] Draft 1: Refined Engineering Plan
- Sequential focus, 16k context.

## [ARCHIVED] Draft 2: Corrected Engineering Plan
- Introduced One-Shot Batching.

## [ARCHIVED] Draft 3: The Final Overhaul Plan
- Integrated parallel workers and basic intent.

## [ARCHIVED] Draft 4: The Operational Overhaul Plan
- High-level throughput and basic operational details.
</details>

---

# 🏎️ Phase 3 Quantum Leap: THE FINAL ENGINEERING SPECIFICATION

## 📋 Mission Objective
Transform the Harper-Edition Assistant into a production-grade, ultra-fast, and hyper-reliable agent. Leverage the M1 chip's 400GB/s bandwidth through **One-Shot Batching**, **Parallel Execution**, and **Robust Operational Rigor**.

---

## 🏗️ Core Architecture: The Reliability Sandwich
Every batch operation follows a strict **Pre-flight -> Execute -> Report** pattern. No step proceeds if the previous step fails.

### 🥪 SECTION A: The Prompt Library (`~/.openclaw/prompt_library/`)
#### 1. Prompt Block Content Template
Each block must follow this structure:
```text
intents: <comma-separated keywords>
block_id: <filename without .txt>

<Instructions>
1. Label taxonomy (INBOX, Promotions, Social, Updates, Forums, Trash, Archive)
2. Decision rules (e.g., Newsletters -> Promotions)
3. Edge cases (2FA, shipping, security)
4. Output format (Strict JSON)
5. Few-shot examples
```

#### 2. Fallback & Configuration
- **Fallback:** If no intent matches, load `harper_base.txt`. If missing, load nothing.
- **Config:** Default path is `~/.openclaw/prompt_library/`, overridable via `harper.promptLibrary.path`.
- **Performance:** Plugin caches blocks with a 60s TTL.

---

### ⚡ SECTION B: Mission 041 — The One-Shot Engine
#### 1. Ollama Batch Request Spec
**Endpoint:** `POST http://localhost:11434/api/chat`
**Body:**
```json
{
  "model": "qwen3-vl:8b",
  "messages": [
    { "role": "system", "content": "<email_cleaner block>" },
    { "role": "user", "content": "<structured email list>" }
  ],
  "stream": false,
  "options": {
    "num_ctx": 8192,
    "num_predict": 1024,
    "temperature": 0
  },
  "format": "json"
}
```

#### 2. JSON Response Schema
**Valid Actions:** `archive`, `label`, `delete`, `skip`.
**Schema:**
```json
{
  "decisions": [
    {
      "id": "<message_id>",
      "action": "archive|label|delete|skip",
      "label": "<label_name_if_action_is_label>"
    }
  ]
}
```

#### 3. JSON Parsing & Recovery (5-Step)
1. `JSON.parse` raw content.
2. Strip markdown fences (`` `json ... ` ``) and retry.
3. Regex extract `{"decisions":[...]}` and retry.
4. Retry Ollama call once with "ONLY valid JSON" instruction.
5. Exit with non-zero on total failure.

---

### 🛡️ SECTION C: Reliability & Execution
#### 1. Pre-Flight Checks
- **Ollama:** Check `/api/tags` for 200 OK.
- **Model:** Verify `qwen3-vl:8b` is present in `ollama list`.
- **Gmail:** Validate OAuth token.
- **Batch:** Exit cleanly if 0 emails are found.

#### 2. Action Execution
- **Validation:** Ensure ID exists, action is valid, and label is in the allowed list.
- **Parallelism:** Max 5 concurrent actions.
- **Error Handling:** Per-action try/catch. Log failures and report specific counts.
- **Idempotency:** Check `processed_emails.db` before every action.

#### 3. Dry-Run Mode (`--dry-run`)
Build prompt, call AI, parse and validate, then **print decisions only** without applying changes or updating the DB.

---

### 🧠 SECTION D: Intelligence & Intent
#### 1. Intent Keyword Map
| Block | Keywords |
|:---|:---|
| `email_cleaner` | sort, mail, email, inbox, clean, triage, archive, newsletters, categorize, organize |
| `calendar_sync` | calendar, schedule, event, meeting, appointment |
| `imsg_responder`| text, message, imsg, imessage, reply to |

#### 2. Session Context
Plugin preserves `event.messages` for multi-turn intent detection (e.g., "yes, do that").

---

### 📈 SECTION E: Success Metrics
| Metric | Target |
|:---|:---|
| Batch Latency | **< 25 seconds** for 20 emails |
| Success Rate | **> 95%** of actions without error |
| JSON Parse | **> 99%** success (with retry) |
| User Fixes | **< 5%** categorization corrections |

---

### 🏎️ SECTION F: M1 Tuning & Interface
- **Context Slider:** Toggle `num_ctx` via Command Center (**8k, 12k, 24k**).
- **KV-Cache:** Enable bit-compression quantization.
- **Summary Budget:** 1024 tokens for deep, informative summaries.
- **Terminal Interface:** `turbo_cleaner_v3.sh --batch [--dry-run] [--limit N]`

---

## 📅 Implementation Order
1. **Stage 1 (Parallel):** Setup Library + M1 Tuning (Quantization & Slider) + Pre-flight Checks.
2. **Stage 2:** Build Harper Intent Router Plugin with fallback logic.
3. **Stage 3:** Refactor Turbo script into One-Shot Batch Mode with Robust JSON recovery.

**Awaiting instruction to begin Stage 1.** 🦞🏎️💨⚡️🎯🏆
