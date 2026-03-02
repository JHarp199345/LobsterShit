/**
 * Shared regex utilities.
 * Consolidates duplicated escape logic across mattermost, feishu, tlon, irc, matrix, msteams.
 */

/**
 * Escape regex metacharacters so user-controlled text is treated literally.
 * Use when building RegExp from user input (mentions, search, etc.).
 */
export function escapeForRegex(input: string): string {
  return input.replaceAll(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
