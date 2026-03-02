/**
 * openclaw — Plugin SDK entry point
 *
 * This file is the TypeScript source barrel for the `openclaw` package.
 * It re-exports the compiled plugin-sdk surface so that:
 *   1. Extensions can import from `openclaw/plugin-sdk` with full type safety.
 *   2. IDE tooling (go-to-definition, etc.) can resolve symbols to declarations.
 *   3. New source modules can be added here and compiled with `pnpm build`.
 *
 * Derived by mapping all `import { ... } from "openclaw/plugin-sdk"` statements
 * across the 377 extension import sites in extensions/**\/src/*.ts.
 *
 * Build: `pnpm canvas:a2ui:bundle && tsdown` (see package.json scripts)
 * Output: dist/plugin-sdk/index.js + dist/plugin-sdk/index.d.ts
 *
 * Runtime package exports (package.json):
 *   "openclaw/plugin-sdk"       → dist/plugin-sdk/index.js
 *   "openclaw/plugin-sdk/account-id" → dist/plugin-sdk/account-id.js
 */

// ── Re-export the full compiled plugin-sdk surface ────────────────────────
// This makes the src/ barrel equivalent to the dist/ output for type purposes.
export * from "../dist/plugin-sdk/plugin-sdk/index.js";
