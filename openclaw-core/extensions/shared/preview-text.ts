/**
 * Shared preview/snippet utilities for message body text.
 * Consolidates duplicated logic across mattermost, msteams, feishu, matrix, bluebubbles, twitch.
 */

/**
 * Collapse whitespace and truncate for preview display (e.g. in logs, UI).
 * Default maxLen 160 matches most extension usage.
 */
export function truncatePreview(text: string | undefined | null, maxLen = 160): string {
  const s = String(text ?? "").replaceAll(/\s+/g, " ").trim();
  return s.slice(0, maxLen);
}

/**
 * Truncate and escape newlines for single-line log output (e.g. JSON-safe preview).
 */
export function previewForLog(text: string | undefined | null, maxLen = 200): string {
  const s = String(text ?? "").slice(0, maxLen).replaceAll(/\n/g, "\\n");
  return s;
}

/**
 * Truncate string to maxLen, optionally appending ellipsis if truncated.
 * Use for API limits (e.g. altText 400, caption 2000) and display truncation.
 */
export function truncateTo(
  text: string | undefined | null,
  maxLen: number,
  options?: { ellipsis?: string }
): string {
  const s = String(text ?? "");
  if (s.length <= maxLen) return s;
  const suffix = options?.ellipsis ?? "";
  const keep = maxLen - suffix.length;
  return keep > 0 ? s.slice(0, keep) + suffix : s.slice(0, maxLen);
}
