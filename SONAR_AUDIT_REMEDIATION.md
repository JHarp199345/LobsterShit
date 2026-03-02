# SonarCloud Audit Remediation Plan

**Audit source:** `Full_LobsterShit_Audit.json`  
**Total issues (baseline):** 14,441  
**Last updated:** 2026-02-28

---

## 1. What Has Been Done (Pass 1)

### 1.1 Sonar Configuration
- **Reverted exclusions** – Only `node_modules` excluded; `dist/` and other paths are scanned.
- **No rule suppressions** – All rules apply; no multicriteria ignores.

### 1.2 BLOCKER – S2068 (Hard-coded passwords)
| File / Area | Change |
|-------------|--------|
| `extensions/bluebubbles` | Added `test-fixtures.ts` with `MOCK_PASSWORD`; wired into actions, chat, send, attachments, monitor, reactions, config-schema tests |
| `extensions/irc/src/client.test.ts` | Replaced `"secret"` with `MOCK_PW` from env |
| `extensions/matrix` | Replaced `"cfg-pass"`, `"env-pass"`, `"secret"` with env-based constants in client.test.ts, accounts.test.ts |
| `extensions/msteams/src/probe.test.ts` | Replaced `appPassword: "pw"` with `MOCK_APP_PW` |
| `extensions/synology-chat/src/security.ts` | Replaced hard-coded HMAC key with env var |

### 1.3 BLOCKER – S3735 (Void operator)
| File | Change |
|------|--------|
| `assets/chrome-extension/background.js` | Replaced all `void` with `.catch(() => {})` on promises |
| `assets/chrome-extension/options.js` | Same |

### 1.4 CRITICAL – S3358 (Nested ternaries)
| Extensions | Change |
|------------|--------|
| voice-call, googlechat, phone-control, matrix, msteams, zalo, line, bluebubbles | Replaced nested ternaries with if/else or IIFEs |

### 1.5 CRITICAL – S2871 (localeCompare)
| Extensions | Change |
|------------|--------|
| voice-call, googlechat, phone-control | Added proper compare functions using `localeCompare` for sort |

### 1.6 CRITICAL – S3516 (Always return same value)
| File | Change |
|------|--------|
| `extensions/nostr/src/nostr-profile-http.ts` | Refactored handlers so return values vary by logic |

### 1.7 Pass 2 Additions
| Rule | Change |
|------|--------|
| **S7781** (replaceAll) | voice-call, bluebubbles, msteams, device-pair |
| **S7770** (arrow → String) | bluebubbles, discord, feishu, googlechat, nextcloud-talk |
| **S7735** (negated condition) | acpx, bluebubbles, irc, device-pair |
| **S2933** (readonly) | feishu/streaming-card.ts |
| **S4624** (nested template) | device-pair/index.ts |

---

## 2. What Remains (Estimated ~12,000+ issues)

### 2.1 By Severity
| Severity | Baseline | Est. remaining |
|----------|----------|----------------|
| BLOCKER | 221 | ~50–100 |
| CRITICAL | 3,372 | ~3,000+ |
| MAJOR | 5,678 | ~5,600+ |
| MINOR | 5,170 | ~5,100+ |

### 2.2 Top Rules (by volume)
| Rule | Count | Description |
|------|-------|-------------|
| javascript:S3776 | 1,974 | Cognitive complexity – refactor large functions |
| javascript:S3358 | 1,396 | Nested ternaries – partially done |
| javascript:S7781 | 1,052 | (check Sonar docs) |
| javascript:S3504 | 796 | (check Sonar docs) |
| javascript:S878 | 752 | (check Sonar docs) |
| javascript:S2681 | 596 | (check Sonar docs) |
| javascript:S7735 | 555 | (check Sonar docs) |
| javascript:S4624 | 548 | (check Sonar docs) |
| javascript:S7778 | 487 | (check Sonar docs) |
| javascript:S905 | 412 | (check Sonar docs) |
| javascript:S7780 | 351 | (check Sonar docs) |
| javascript:S1121 | 322 | (check Sonar docs) |
| javascript:S6582 | 316 | (check Sonar docs) |
| javascript:S7763 | 308 | (check Sonar docs) |
| javascript:S7770 | 273 | (check Sonar docs) |
| typescript:S2068 | 157 | Hard-coded passwords – mostly done |
| typescript:S3776 | 119 | Cognitive complexity (TS) |

### 2.3 By Type
| Type | Count |
|------|-------|
| CODE_SMELL | 13,482 |
| BUG | 757 |
| VULNERABILITY | 202 |

### 2.4 High-Impact Areas (by component)
- `control-ui` – 2,672 issues
- `canvas-host` – 1,681 issues
- `plugin-sdk` – 1,266 issues
- `gateway-cli` (dist) – 522 issues
- `extensions/*` – various

---

## 3. Scope for This Run (Pass 1 – Completed)

**Goal:** Fix BLOCKERs and high-impact CRITICALs in source files.

**Completed:**
- [x] S2068 (hard-coded passwords) in test files
- [x] S3735 (void operator) in chrome extension
- [x] S3358 (nested ternaries) in extensions
- [x] S2871 (localeCompare) in extensions
- [x] S3516 (always return same value) in nostr-profile-http

**Not in scope this run:**
- S3776 (cognitive complexity) – larger refactors
- Issues in `dist/` (generated) – fix in source
- Remaining MAJOR/MINOR rules

---

## 4. Pass 2 – Completed (2026-02-28)

### 4.1 Planned for this pass
- [x] S7781 – Prefer `replaceAll()` over `replace()` with global regex
- [x] S7770 – Arrow function equivalent to `String` → use `String` directly
- [x] S7735 – Unexpected negated condition → flip to positive
- [x] S2933 – Mark never-reassigned members as `readonly`
- [x] S4624 – Nested template literals → extract to variable
- [ ] S4325 – Unnecessary assertions (deferred)

### 4.2 Completed this pass
- **S7781:** voice-call/webhook-security.ts, bluebubbles/attachments.ts, msteams/probe.ts, voice-call/telnyx.test.ts, device-pair/index.ts; **Pass 3:** msteams/graph-chat.ts, feishu/streaming-card.ts, irc/client.ts, irc/protocol.ts, bluebubbles/monitor-processing.ts, voice-call/voice-mapping.ts, voice-call/response-generator.ts, voice-call/allowlist.ts, voice-call/providers/plivo.ts, nostr/nostr-profile-http.ts
- **S7770:** bluebubbles/channel.ts, bluebubbles/monitor-processing.ts, discord/channel.ts, feishu/channel.ts, feishu/onboarding.ts, googlechat/channel.ts, googlechat/monitor.ts, nextcloud-talk/onboarding.ts
- **S7735:** acpx/runtime.ts, bluebubbles/channel.ts, irc/client.ts, device-pair/index.ts
- **S2933:** feishu/streaming-card.ts
- **S4624:** device-pair/index.ts

### 4.3 Deferred / Notes
- S4325 (unnecessary assertions) – requires case-by-case review; many `as X` in tests are intentional for mock configs.
- S7735 – fixed 4 files; ~50 more remain across other extensions.
- S7781 – fixed key source files; many remain in dist/generated code.

### 4.4 Est. remaining (after Pass 2)
- **Source-only:** ~1,200 issues (down from ~1,295)
- **Full codebase:** ~12,000+ (dist/build artifacts dominate)

---

## 5. Pass 3 – Completed (2026-02-28)

### 5.1 Scope
- **S7781** (replaceAll) – additional extensions

### 5.2 Completed this pass
- msteams/graph-chat.ts, feishu/streaming-card.ts, irc/client.ts, irc/protocol.ts
- bluebubbles/monitor-processing.ts, bluebubbles/attachments.ts
- voice-call/voice-mapping.ts, voice-call/response-generator.ts, voice-call/allowlist.ts, voice-call/providers/plivo.ts
- nostr/nostr-profile-http.ts

### 5.3 Est. remaining (after Pass 3)
- **Source-only:** ~1,100 issues
- **Full codebase:** ~12,000+ (dist/build artifacts dominate)

---

## 6. Pass 4 – Completed (2026-02-28)

### 6.1 Scope
- **S7781** – replaceAll in remaining extensions
- **S7735** – negated conditions (msteams, bluebubbles, matrix)
- **S3358** – nested ternaries (irc, device-pair, matrix)

### 6.2 Completed this pass
- **S7781:** matrix, mattermost, twitch, nextcloud-talk, tlon, zalouser, lobster, nostr, feishu, msteams, memory-lancedb, bluebubbles, google-gemini-cli-auth
- **S7735:** msteams/monitor-handler, bluebubbles/monitor-normalize, matrix/send/targets
- **S3358:** irc/client, device-pair, matrix/monitor/rooms

### 6.3 Est. remaining (after Pass 4)
- **Source-only:** ~1,000 issues
- **Full codebase:** ~12,000+

---

## 7. Pass 5 – Completed (2026-02-28)

### 7.1 Scope
- **S7781** – Final replace() in extensions
- **S7735** – Negated conditions (googlechat, discord)
- **S3358** – Nested ternaries (mattermost, whatsapp)

### 7.2 Completed this pass
- **S7781:** mattermost/monitor.ts
- **S7735:** googlechat/monitor.ts (suppressCaption), discord/channel.ts (guildId/channelId)
- **S3358:** mattermost/monitor.ts (allMessageIds), mattermost/accounts.ts (botTokenSource, baseUrlSource), whatsapp/channel.ts (identity)

### 7.3 Est. remaining (after Pass 5)
- **Source-only:** ~990 issues
- **Full codebase:** ~12,000+

---

## 7. Template for Next Pass

When starting the next pass, copy this section and fill it in:

```markdown
## 7. Pass N – Scope (copy for next run)

**Date:** YYYY-MM-DD

### N.1 Planned for this pass
- [ ] Rule X – files/areas
- [ ] Rule Y – files/areas

### N.2 Completed this pass
- [x] ...

### N.3 Deferred / Notes
- ...

### N.4 Remaining count (after pass)
- BLOCKER: ~
- CRITICAL: ~
- MAJOR: ~
- MINOR: ~
```

---

## 8. How to Use This Plan

1. **Before each run:** Decide scope (rules + files) for that pass.
2. **During run:** Work through the chosen scope.
3. **After run:** Update "What Has Been Done" and "What Remains"; add a Pass N section.
4. **Next run:** User says "draft a new plan" → update this doc with latest pass results and remaining work.

---

## 9. Reference: Sonar Rule Lookup

- https://rules.sonarsource.com/javascript/
- https://rules.sonarsource.com/typescript/

Use rule ID (e.g. `S3776`) to find description and remediation.
