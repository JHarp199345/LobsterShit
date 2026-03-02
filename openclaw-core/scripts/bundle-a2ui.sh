#!/usr/bin/env bash
# bundle-a2ui.sh
#
# Bundles the A2UI Lit web-component (openclaw-a2ui-host) into a single
# browser-ready IIFE file at dist/canvas-host/a2ui/a2ui.bundle.js.
#
# The A2UI is a Lit v3 / @lit-labs/signals component tree that renders
# the agent-to-user canvas surface inside the OpenClaw desktop client.
#
# Build strategy:
#   • If src/canvas-host/a2ui/index.ts exists → bundle with tsdown (rolldown)
#   • Otherwise → the committed dist bundle is kept as-is (pre-built artifact)
#
# Framework: Lit 3 (LitElement + html/css tagged templates)
# Bundler:   tsdown ^0.20.3  (rolldown-based, configured inline)
# Output:    dist/canvas-host/a2ui/a2ui.bundle.js   (IIFE, no external deps)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_ENTRY="$ROOT_DIR/src/canvas-host/a2ui/index.ts"
OUT_DIR="$ROOT_DIR/dist/canvas-host/a2ui"
OUT_FILE="$OUT_DIR/a2ui.bundle.js"

# ── Verify tsdown is available ─────────────────────────────────────────────
TSDOWN="$ROOT_DIR/node_modules/.bin/tsdown"
if [[ ! -x "$TSDOWN" ]]; then
  echo "bundle-a2ui: tsdown not found at $TSDOWN — skipping build" >&2
  exit 0
fi

# ── Skip build if source doesn't exist (use committed artifact) ───────────
if [[ ! -f "$SRC_ENTRY" ]]; then
  echo "bundle-a2ui: source not found at $SRC_ENTRY"
  if [[ -f "$OUT_FILE" ]]; then
    echo "bundle-a2ui: using committed artifact at $OUT_FILE — nothing to do."
  else
    echo "bundle-a2ui: WARNING — no source and no committed bundle. Canvas UI will be missing." >&2
    mkdir -p "$OUT_DIR"
    # Emit a minimal no-op bundle so downstream steps don't fail
    cat > "$OUT_FILE" << 'NOOP'
/* openclaw-a2ui-host: bundle not built */
if (!customElements.get("openclaw-a2ui-host")) {
  customElements.define("openclaw-a2ui-host", class extends HTMLElement {});
}
NOOP
  fi
  exit 0
fi

echo "bundle-a2ui: bundling $SRC_ENTRY → $OUT_FILE"

mkdir -p "$OUT_DIR"

# Bundle as IIFE so it can be loaded via a plain <script src> tag.
# All Lit dependencies are inlined (no external imports in browser context).
"$TSDOWN" \
  "$SRC_ENTRY" \
  --format iife \
  --platform browser \
  --out-dir "$OUT_DIR" \
  --out-extension ".js" \
  --no-dts \
  --no-sourcemap \
  --minify \
  --target es2020

# tsdown names the output after the input file; rename to the expected filename.
TSDOWN_OUT="$OUT_DIR/index.js"
if [[ -f "$TSDOWN_OUT" && "$TSDOWN_OUT" != "$OUT_FILE" ]]; then
  mv "$TSDOWN_OUT" "$OUT_FILE"
fi

echo "bundle-a2ui: done → $(du -sh "$OUT_FILE" | cut -f1) written to $OUT_FILE"
