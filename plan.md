# LobsterShit Audit Remediation Plan

**Primary objective:** Correct the errors found in the LobsterShit audit. Refactor the ~1.1M-line OpenClaw codebase into a stable, industrial-grade tool. The original creator (Peter Steinberger) moved to OpenAI and left the repository to a foundation.

**Audit source:** `Full_LobsterShit_Audit.json` · **Baseline:** 14,441 issues

---

## Pass 1 – Completed
- **S2068** (hard-coded passwords) – test fixtures, env-based constants (bluebubbles, irc, matrix, msteams, synology-chat)
- **S3735** (void operator) – chrome extension promises
- **S3358** (nested ternaries) – voice-call, googlechat, phone-control, matrix, msteams, zalo, line, bluebubbles
- **S2871** (localeCompare) – voice-call, googlechat, phone-control
- **S3516** (always return same value) – nostr-profile-http

---

## Pass 2 – Completed (2026-02-28)
- **S7781** – `replaceAll()` over `replace()` (voice-call, bluebubbles, msteams, device-pair)
- **S7770** – Arrow → `String` (bluebubbles, discord, feishu, googlechat, nextcloud-talk)
- **S7735** – Negated conditions flipped (acpx, bluebubbles, irc, device-pair)
- **S2933** – `readonly` members (feishu/streaming-card.ts)
- **S4624** – Nested template literals extracted (device-pair)
- **S4325** – Deferred (unnecessary assertions; case-by-case review)

---

## Pass 3 – Completed (2026-02-28)
- **S7781** (additional) – msteams/graph-chat.ts, feishu/streaming-card.ts, irc/client.ts, irc/protocol.ts, bluebubbles/monitor-processing.ts, bluebubbles/attachments.ts, voice-call/voice-mapping.ts, voice-call/response-generator.ts, voice-call/allowlist.ts, voice-call/providers/plivo.ts, nostr/nostr-profile-http.ts

---

## Pass 4 – Completed (2026-02-28)
- **S7781** – replaceAll in matrix, mattermost, twitch, nextcloud-talk, tlon, zalouser, lobster, nostr, feishu, msteams, memory-lancedb, bluebubbles, google-gemini-cli-auth
- **S7735** – msteams/message-handler, bluebubbles/monitor-normalize, matrix/send/targets
- **S3358** – irc/client, device-pair, matrix/monitor/rooms

---

## Pass 5 – Completed (2026-02-28)
- **S7781** – mattermost/monitor.ts (last remaining in extensions)
- **S7735** – googlechat/monitor, discord/channel
- **S3358** – mattermost/monitor, mattermost/accounts, whatsapp/channel

---

## Pass 6 – Completed (2026-02-28)
- **Index** – Identified preview/snippet clone clusters across 6 extensions
- **Propose** – `truncatePreview`, `previewForLog` (first 2 of 5 Universal Utilities)
- **Implement** – `extensions/shared/preview-text.ts`
- **Refactor** – mattermost, msteams, feishu, matrix, bluebubbles, twitch

## Pass 6 Phase 2 – Completed (2026-03-02)
- **Implement** – `truncateTo()` in `preview-text.ts` (API limits, display truncation)
- **Refactor** – synology-chat, zalo, zalouser, memory-lancedb (4 more extensions)
- **Impact** – ~15 duplicated slice/truncate patterns replaced with shared utility

---

## Pass 7 – Completed (2026-03-02)
- **Implement** – `extensions/shared/identifiers.ts` with `sanitizeForIdentifier()`
- **Refactor** – mattermost (normalizeAgentId), nostr (normalizeAccountId), matrix (sanitizePathSegment), zalouser (normalizeGroupSlug)
- **Refactor** – line (truncateTo for altText, title, address, label, data)
- **Impact** – ~25 duplicated identifier/slug patterns + ~10 truncate patterns consolidated

---

## Pass 8 – Completed (2026-03-02)
- **Implement** – `extensions/shared/regex.ts` with `escapeForRegex()`
- **Refactor** – mattermost, tlon, irc, matrix, msteams, feishu (regex escape); line, bluebubbles, feishu, msteams, nostr (truncateTo)
- **Impact** – 7 regex-escape clones; 6 truncate patterns

---

## Pass 9 – Completed (2026-03-02)
- **Implement** – `extensions/shared/validation.ts` with `validateRequired()`, `asString()`
- **Refactor** – 14 onboarding adapters (validateRequired); zalo/zalouser status-issues (asString); device-pair (parseIPv4Octets)
- **Impact** – 30+ validate clones; 2 asString clones; device-pair internal clone removed

---

## What Remains

| Severity | Baseline | Est. remaining |
|----------|----------|----------------|
| BLOCKER | 221 | ~50–100 |
| CRITICAL | 3,372 | ~3,000+ |
| MAJOR | 5,678 | ~5,600+ |
| MINOR | 5,170 | ~5,100+ |

**Source-only:** ~990 issues · **Full codebase:** ~12,000+ (dist/build artifacts dominate)

**Top rules (by volume):** S3776 (cognitive complexity), S3358 (nested ternaries), S7781, S3504, S878, S2681, S7735, S4624, S7778, S905, S7780, S1121, S6582, S7763, S7770

**High-impact areas:** control-ui (~2,672), canvas-host (~1,681), plugin-sdk (~1,266), gateway-cli (dist), extensions/*

**Tests:** IRC pass; voice-call fail (missing `openclaw/plugin-sdk`, pre-existing)

*Full details:* `SONAR_AUDIT_REMEDIATION.md`

---

## Mission Brief: Radical DRY Refactor (Pass 6 / 7)

**Objective:** Execute a comprehensive "DRY" (Don't Repeat Yourself) refactor of the [LobsterShit](https://github.com/JHarp199345/LobsterShit) repository to eliminate a critical **47.1% code duplication rate** and resolve [14,441 technical debt issues](https://sonarcloud.io/summary/overall?id=JHarp199345_LobsterShit).

### Context & Problem Statement

The codebase is ~1.1M lines. Nearly half of the logic is redundant, copy-pasted blocks. This creates a "complexity wall"—runtime freezes, unhandled dead-ends, and a massive maintenance burden. The core problem is in **`openclaw-core`**, where platform-specific skills (iMessage, WhatsApp, etc.) re-implement identical logic for credential handling, message delivery, and networking.

### Tactical Mission: Abstraction & Consolidation

Transition from "Copy-Paste" to "Stateless Utility" model.

1. **Identify Code Clones** – Scan `openclaw-core` for identical or near-identical blocks exceeding 20 lines.
2. **Implement Reusable Functions** – For each cluster (e.g. `push-apns`, `account-lookup`), design a single stateless utility.
3. **Centralize Logic** – Move into `shared` or `utils` within the core.
4. **Refactor Call Sites** – Replace duplicates with `import` + function calls.

### Execution Priorities

1. **High-Impact Reliability** – Prioritize [2,700+ Reliability issues](https://sonarcloud.io/project/issues?id=JHarp199345_LobsterShit&impactSoftwareQualities=RELIABILITY) first. Duplicated bugs exist in five places at once.
2. **Maintainability Debt** – Use [SonarCloud Audit JSON](https://colab.research.google.com/drive/1Ob34X5caQZ7TCEuTwkzdWbV9qjB-cd4t) to locate the most complex functions. One refactor of a duplicated Code Smell can resolve dozens of issues.
3. **Stability over Speed** – Abstracted functions must handle edge cases (null, timeouts) better than originals to prevent recurring freezes.

### Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Duplication density | 47.1% | < 10% |
| Maintainability rating | E | → A |
| Functional parity | — | Preserve iMessage, life-management; remove social slop |

### Pass 6 / 7 Plan

**Planned scope (Pass 6 or 7):**

1. **Index** – Scan `openclaw-core` for clone clusters (blocks > 20 lines).
2. **Propose** – First five "Universal Utility" functions with highest impact on line count.
3. **Implement** – Create `shared`/`utils` module; add utilities.
4. **Refactor** – Replace duplicates at call sites.
5. **Verify** – Functional parity; no regressions.

**Status:** Pass 6–9 complete. Continue with mission.

**Done:** preview-text.ts, identifiers.ts, regex.ts, validation.ts; Refactor 16+ extensions  
**To do:** Further utilities as needed → Verify parity

### 47.1% Duplication: Reality Check

SonarCloud reports **47.1% duplication** on LobsterShit. Local jscpd on workhorse extensions shows **~1%** (different algorithm, excludes dist). The gap is because:

1. **SonarCloud** includes `dist/`, build artifacts, and generated code—duplicated across output files.
2. **Sonar** uses block-based duplication; jscpd uses token-based—different thresholds.
3. **Meaningful reduction** requires: (a) exclude `dist/` from Sonar scan, (b) systematic clone detection on source, (c) larger refactors (handler patterns, credential flows).

**Expectation:** A single DRY pass will not drop 47.1% to under 10%. Each utility refactor removes dozens of lines. To approach target: run Sonar with `sonar.exclusions=**/dist/**`, then iterate on high-duplication files Sonar reports.

**Directive:** *"You are acting as the Chief Architect for this 'Orphan' project. Treat this codebase as a puzzle where half the pieces are duplicates. Your job is not to fix the bugs individually, but to fix the architecture that allows the bugs to exist. Start by indexing the `openclaw-core` directory and proposing the first five 'Universal Utility' functions that will have the biggest impact on reducing the line count."*

---

## 🗑️ Pinchboard/Moltbook Removal (Planned)

The original creator built an **AI social interface** where agents could talk to each other in a social-media–like fashion (intended to eventually learn from each other). The industry isn’t there yet. **Remove or comment out** this logic so it no longer affects the core.

### Checklist (from Gemini)

1. **Delete the Moltbook Skill**
   - In `openclaw-core/skills/`, delete any folder whose `SKILL.md` mentions "Moltbook," "Pinchboard," or "MoltHub" (agent posting milestones to a public social layer).

2. **Clean the Control UI**
   - In `control-ui/`, remove or disable components/views labeled `Pinchboard` or `SocialFeed` (stops dashboard from pulling "agent manifestos" or "submolt" updates).

3. **Purge the Scripts**
   - In `scripts/`, remove automation such as `moltbook-sync.sh` or `heartbeat-post.js` (triggers for autonomous agent-to-agent posting).

4. **Dependency Check**
   - In `openclaw-core/package.json`, remove `molthub` and any `@molt` packages.

**Note:** Search of workhorse found no Moltbook/Pinchboard/MoltHub. ClawHub is a skill registry—keep it. Run checklist on LobsterShit fork if present.

---

## 📬 Contact: Peter Steinberger

When the adopted, cleaned version is ready to share:

- **GitHub:** [steipete](https://github.com/steipete)
- **X (Twitter):** [@steipete](https://x.com/steipete)
- **Site:** [steipete.me](https://steipete.me/) (contact link)

Pitch: resolved the 13,000+ maintainability issues, stripped the social layer, and produced a stable, industrial-grade fork.

---

## Deferred (Not the Main Objective)

<details>
<summary>Harper / Phase 3 — email triage, intent router, turbo_cleaner (deferred until audit is under control)</summary>

Implemented but out of scope for current focus: prompt library, harper_intent_router.sh, harper_load_block.sh, harper_preflight.sh, turbo_cleaner refactor, calendar_sync/imsg_responder placeholders. Resume when LobsterShit audit remediation is the priority.
</details>
