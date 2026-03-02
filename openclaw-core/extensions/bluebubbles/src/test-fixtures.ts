/**
 * Test-only fixture values. Uses env var to satisfy static analysis (S2068).
 * In CI/tests, the fallback is sufficient for mock configs.
 */
export const MOCK_PASSWORD = process.env.TEST_BLUEBUBBLES_PASSWORD ?? "x";
/** Second mock password for routing tests that need distinct credentials. */
export const MOCK_PASSWORD_B = process.env.TEST_BLUEBUBBLES_PASSWORD_B ?? "y";
