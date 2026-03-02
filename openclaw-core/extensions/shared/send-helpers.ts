/**
 * Shared utilities for extension send/outbound logic.
 *
 * These helpers eliminate the boilerplate that was copy-pasted verbatim across
 * every extension's send.ts and monitor.ts:
 *
 *   - convertMarkdownForChannel  (resolveMarkdownTableMode + convertMarkdownTables 2-liner)
 *   - recordOutboundActivity     (channel.activity.record with direction:"outbound")
 *   - normalizeTextWithMedia     (join message text with a fallback media URL)
 *   - isHttpUrl                  (simple https?:// guard)
 *   - throwIfNotOk               (fetch response error extraction)
 */

/**
 * Minimal structural type for the channel-text runtime slice.
 *
 * We use structural typing (duck-typing) rather than importing PluginRuntime
 * directly so this shared helper stays free of hard plugin-sdk coupling.
 * The `cfg` field mirrors the actual optional-Partial signature of
 * `resolveMarkdownTableMode` so TypeScript assignment is compatible.
 */
type MarkdownRuntime = {
  channel: {
    text: {
      resolveMarkdownTableMode(params: {
        cfg?: unknown;
        channel?: string | null;
        accountId?: string | null;
      }): unknown;
      convertMarkdownTables(text: string, mode: unknown): string;
    };
  };
};

/** Minimal runtime shape required for activity recording. */
type ActivityRuntime = {
  channel: {
    activity: {
      record(params: {
        channel: string;
        accountId: string;
        direction: "inbound" | "outbound";
      }): void;
    };
  };
};

/**
 * Resolve markdown table mode and convert tables in one call.
 *
 * Replaces the two-liner found in every extension send/monitor file:
 *   const tableMode = runtime.channel.text.resolveMarkdownTableMode({ cfg, channel, accountId });
 *   const converted = runtime.channel.text.convertMarkdownTables(text, tableMode);
 */
export function convertMarkdownForChannel(
  runtime: MarkdownRuntime,
  params: { cfg?: unknown; channel?: string | null; accountId?: string | null },
  text: string,
): string {
  const tableMode = runtime.channel.text.resolveMarkdownTableMode(params);
  return runtime.channel.text.convertMarkdownTables(text, tableMode);
}

/**
 * Record an outbound channel activity event.
 *
 * Replaces the 3-line block found in every extension send.ts:
 *   runtime.channel.activity.record({ channel, accountId, direction: "outbound" });
 */
export function recordOutboundActivity(
  runtime: ActivityRuntime,
  params: { channel: string; accountId: string },
): void {
  runtime.channel.activity.record({
    channel: params.channel,
    accountId: params.accountId,
    direction: "outbound",
  });
}

/**
 * Join message text with an optional media URL fallback.
 *
 * Replaces the `normalizeMessage` + `isHttpUrl` pattern in mattermost/send.ts
 * and similar patterns elsewhere.
 */
export function normalizeTextWithMedia(text: string, mediaUrl?: string): string {
  const trimmed = text.trim();
  const media = mediaUrl?.trim();
  return [trimmed, media].filter(Boolean).join("\n");
}

/** Return true if value looks like an http/https URL. */
export function isHttpUrl(value: string): boolean {
  return /^https?:\/\//i.test(value);
}

/**
 * Read an error body from a failed fetch Response and throw a formatted Error.
 *
 * Replaces the repeated:
 *   const errorBody = await response.text().catch(() => "");
 *   throw new Error(`XXX failed (${response.status}): ${errorBody || "unknown"}`);
 */
export async function throwIfNotOk(response: Response, prefix: string): Promise<void> {
  if (response.ok) return;
  const errorBody = await response.text().catch(() => "");
  throw new Error(`${prefix} (${response.status}): ${errorBody || "unknown"}`);
}
