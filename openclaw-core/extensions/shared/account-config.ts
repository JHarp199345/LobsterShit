import type { OpenClawConfig } from "openclaw/plugin-sdk";

/**
 * A structural subset of any OpenClaw-compatible config that carries a channels map.
 * Using this instead of OpenClawConfig directly lets subtypes like CoreConfig or
 * ClawdbotConfig pass without explicit casting at call sites.
 */
type AnyChannelConfig = { channels?: Record<string, unknown> | null | undefined };

/**
 * Merge a channel's top-level config with account-specific overrides.
 *
 * The algorithm:
 *   1. Grab the raw channel section (`cfg.channels[channelKey]`).
 *   2. Strip `"accounts"` and any caller-supplied `omitFromBase` keys so per-account
 *      overrides never bleed back into base config.
 *   3. Look up the account-specific sub-object from `channelConfig.accounts[accountId]`.
 *   4. Spread base then account so account keys win.
 *
 * This replaces the boilerplate `resolveAccountConfig` + `mergeXXXAccountConfig`
 * pair that was copy-pasted verbatim across every extension's accounts.ts file.
 */
export function mergeChannelAccountConfig<T extends Record<string, unknown>>(
  cfg: AnyChannelConfig | OpenClawConfig,
  channelKey: string,
  accountId: string,
  omitFromBase: string[] = [],
): T {
  const channelRaw =
    ((cfg as AnyChannelConfig).channels as Record<string, unknown> | undefined)?.[channelKey] ??
    {};
  const omitSet = new Set(["accounts", ...omitFromBase]);
  const base = Object.fromEntries(
    Object.entries(channelRaw).filter(([k]) => !omitSet.has(k)),
  ) as T;
  const accounts = (channelRaw as { accounts?: Record<string, unknown> }).accounts;
  const accountOverride = (accounts?.[accountId] ?? {}) as Partial<T>;
  return { ...base, ...accountOverride };
}
