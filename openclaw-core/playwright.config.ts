import { defineConfig, devices } from "@playwright/test";

const GATEWAY_PORT = process.env.OPENCLAW_GATEWAY_PORT || "19001";
const BASE_URL = `http://127.0.0.1:${GATEWAY_PORT}`;

export default defineConfig({
  testDir: "./tests/e2e",
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: 0,
  workers: 1,
  reporter: "list",
  use: {
    baseURL: BASE_URL,
    trace: "on-first-retry",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
  timeout: 60_000,
});
