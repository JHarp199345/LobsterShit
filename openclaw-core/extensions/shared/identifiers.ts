/**
 * Shared identifier/slug sanitization utilities.
 * Consolidates duplicated logic across mattermost, nostr, matrix, zalouser.
 */

export type SanitizeForIdentifierOptions = {
  /** Replacement character for invalid chars (default: "_") */
  replaceChar?: "_" | "-";
  /** Max length; truncate if longer (default: no limit) */
  maxLen?: number;
  /** Fallback when result is empty (default: "") */
  default?: string;
  /** Allow dots in identifier, e.g. for path segments (default: true) */
  allowDots?: boolean;
  /** Alphanumeric only; replace all other chars (default: false) */
  alphanumericOnly?: boolean;
};

/**
 * Sanitize a string for use as an identifier, slug, or path segment.
 * Trims, lowercases, replaces invalid chars, strips leading/trailing separators.
 */
export function sanitizeForIdentifier(
  value: string | undefined | null,
  options: SanitizeForIdentifierOptions = {},
): string {
  const {
    replaceChar = "_",
    maxLen,
    default: fallback = "",
    allowDots = true,
    alphanumericOnly = false,
  } = options;

  const trimmed = String(value ?? "").trim().toLowerCase();
  if (!trimmed) return fallback;

  const invalidChars = alphanumericOnly
    ? /[^a-z0-9]+/g
    : allowDots
      ? /[^a-z0-9._-]+/g
      : /[^a-z0-9_-]+/g;
  const escaped = replaceChar === "-" ? "\\-" : "\\_";
  const edgeRegex = new RegExp(`^${escaped}+|${escaped}+$`, "g");

  let s = trimmed.replaceAll(invalidChars, replaceChar).replaceAll(edgeRegex, "");
  s = s || fallback;

  if (maxLen != null && s.length > maxLen) {
    s = s.slice(0, maxLen);
  }
  return s;
}
