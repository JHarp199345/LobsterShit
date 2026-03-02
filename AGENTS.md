# AGENTS.md

## Cursor Cloud specific instructions

### Project structure

This repository wraps `openclaw-core/` which is a **dist-only checkout** of the [OpenClaw](https://github.com/openclaw/openclaw) multi-channel AI gateway. The compiled JS lives in `openclaw-core/dist/`; there is no `src/` directory. Extension TypeScript source and tests live under `openclaw-core/extensions/`.

### Package manager & dependencies

- **pnpm** (pinned to `10.23.0` in `packageManager`; v10.30.2+ works).
- Run `pnpm install` from `/workspace/openclaw-core/`.
- Lockfile is `package-lock.json` (npm format); pnpm generates its own `pnpm-lock.yaml` on first install.

### Running the gateway

Start the gateway in the foreground (channels skipped for local dev):

```bash
cd /workspace/openclaw-core
OPENCLAW_SKIP_CHANNELS=1 node openclaw.mjs gateway run --port 18789 --auth none --bind loopback --allow-unconfigured
```

First run may require: `node openclaw.mjs config set gateway.mode local`

Health check: `node openclaw.mjs gateway health --port 18789`

The Control UI has been disabled in this fork; use the TUI (`node openclaw.mjs tui`) for interactive use instead.

### Lint

```bash
cd /workspace/openclaw-core && pnpm lint
```

Uses `oxlint --type-aware`. Expect 0 errors (warnings are expected in the dist JS).

### Tests

Unit tests (`pnpm test:fast`) require `vitest.unit.config.ts` and the `src/` directory, neither of which exist in this dist-only checkout. Extension tests also import from `../../../src/` paths that are absent. **Tests cannot run in this checkout.**

### CLI reference

All CLI commands run from `/workspace/openclaw-core`:

```bash
node openclaw.mjs --help          # list all commands
node openclaw.mjs doctor          # health checks + diagnostics
node openclaw.mjs models list     # list configured models
node openclaw.mjs gateway call <method>  # RPC call to running gateway
```

### Gotchas

- `systemd` user services are unavailable in the container; always run the gateway in the foreground.
- The `scripts/` directory in `openclaw-core/` only contains `approval-watcher.mjs`; scripts referenced by `package.json` (e.g. `run-node.mjs`, `test-parallel.mjs`) are absent from this dist checkout.
- Format check (`pnpm format:check`) reports issues in dist JS files — this is expected and not actionable.
