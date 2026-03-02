/**
 * Shared validation utilities for onboarding prompts and forms.
 * Consolidates duplicated logic across feishu, nextcloud-talk, zalouser, msteams,
 * tlon, googlechat, irc, bluebubbles, matrix, mattermost, twitch, zalo.
 */

/**
 * Validator that returns undefined when value is non-empty (trimmed), else "Required".
 * Use for required string fields in onboarding prompts.
 */
export function validateRequired(value: unknown): string | undefined {
  return String(value ?? "").trim() ? undefined : "Required";
}

/**
 * Coerce value to string for status/account parsing. Returns undefined for non-string/non-number.
 */
export function asString(value: unknown): string | undefined {
  return typeof value === "string" ? value : typeof value === "number" ? String(value) : undefined;
}
