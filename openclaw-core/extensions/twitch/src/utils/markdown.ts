/**
 * Markdown utilities for Twitch chat
 *
 * Twitch chat doesn't support markdown formatting, so we strip it before sending.
 * Based on OpenClaw's markdownToText in src/agents/tools/web-fetch-utils.ts.
 */

/**
 * Strip markdown formatting from text for Twitch compatibility.
 *
 * Removes images, links, bold, italic, strikethrough, code blocks, inline code,
 * headers, and list formatting. Replaces newlines with spaces since Twitch
 * is a single-line chat medium.
 *
 * @param markdown - The markdown text to strip
 * @returns Plain text with markdown removed
 */
export function stripMarkdownForTwitch(markdown: string): string {
  return (
    markdown
      // Images
      .replaceAll(/!\[[^\]]*]\([^)]+\)/g, "")
      // Links
      .replaceAll(/\[([^\]]+)]\([^)]+\)/g, "$1")
      // Bold (**text**)
      .replaceAll(/\*\*([^*]+)\*\*/g, "$1")
      // Bold (__text__)
      .replaceAll(/__([^_]+)__/g, "$1")
      // Italic (*text*)
      .replaceAll(/\*([^*]+)\*/g, "$1")
      // Italic (_text_)
      .replaceAll(/_([^_]+)_/g, "$1")
      // Strikethrough (~~text~~)
      .replaceAll(/~~([^~]+)~~/g, "$1")
      // Code blocks
      .replaceAll(/```[\s\S]*?```/g, (block) => block.replaceAll(/```[^\n]*\n?/g, "").replaceAll("```", ""))
      // Inline code
      .replaceAll(/`([^`]+)`/g, "$1")
      // Headers
      .replaceAll(/^#{1,6}\s+/gm, "")
      // Lists
      .replaceAll(/^\s*[-*+]\s+/gm, "")
      .replaceAll(/^\s*\d+\.\s+/gm, "")
      // Normalize whitespace
      .replaceAll("\r", "") // Remove carriage returns
      .replaceAll(/[ \t]+\n/g, "\n") // Remove trailing spaces before newlines
      .replaceAll("\n", " ") // Replace newlines with spaces (for Twitch)
      .replaceAll(/[ \t]{2,}/g, " ") // Reduce multiple spaces to single
      .trim()
  );
}

/**
 * Simple word-boundary chunker for Twitch (500 char limit).
 * Strips markdown before chunking to avoid breaking markdown patterns.
 *
 * @param text - The text to chunk
 * @param limit - Maximum characters per chunk (Twitch limit is 500)
 * @returns Array of text chunks
 */
export function chunkTextForTwitch(text: string, limit: number): string[] {
  // First, strip markdown
  const cleaned = stripMarkdownForTwitch(text);
  if (!cleaned) {
    return [];
  }
  if (limit <= 0) {
    return [cleaned];
  }
  if (cleaned.length <= limit) {
    return [cleaned];
  }

  const chunks: string[] = [];
  let remaining = cleaned;

  while (remaining.length > limit) {
    // Find the last space before the limit
    const window = remaining.slice(0, limit);
    const lastSpaceIndex = window.lastIndexOf(" ");

    if (lastSpaceIndex === -1) {
      // No space found, hard split at limit
      chunks.push(window);
      remaining = remaining.slice(limit);
    } else {
      // Split at the last space
      chunks.push(window.slice(0, lastSpaceIndex));
      remaining = remaining.slice(lastSpaceIndex + 1);
    }
  }

  if (remaining) {
    chunks.push(remaining);
  }

  return chunks;
}
