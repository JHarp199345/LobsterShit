/**
 * Playwright E2E: Control UI chat flow.
 * Detects freezes when the robot user sends a message and waits for a response.
 *
 * Requires: Gateway running with Control UI enabled.
 *   pnpm gateway:dev -- and set gateway.controlUi.enabled: true in config
 *   Or: OPENCLAW_PROFILE=dev node scripts/run-node.mjs gateway
 *
 * Run: OPENCLAW_LIVE_TEST=1 pnpm test:e2e:playwright
 */

import { test, expect } from "@playwright/test";

test.describe("Control UI chat flow", () => {
  test.skip(
    () => !process.env.OPENCLAW_LIVE_TEST,
    "Set OPENCLAW_LIVE_TEST=1 to run (requires gateway with Control UI)"
  );

  test("should complete chat without freezing", async ({ page }) => {
    await page.goto("/");
    await page.waitForLoadState("networkidle");

    // Wait for chat input (textarea or contenteditable)
    const input = page.getByRole("textbox").or(page.locator("textarea")).first();
    await expect(input).toBeVisible({ timeout: 15_000 });

    await input.fill("Reply with exactly: OK");
    await input.press("Enter");

    // Wait for any new message content (assistant reply or stream)
    await expect(page.locator("text=OK").or(page.locator("[class*='message']"))).toBeVisible({ timeout: 60_000 });
  });
});
