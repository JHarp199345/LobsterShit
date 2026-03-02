import type { ClawdbotConfig } from "openclaw/plugin-sdk";
import { createAccountListHelpers } from "openclaw/plugin-sdk";
import { normalizeAccountId } from "openclaw/plugin-sdk/account-id";
import { mergeChannelAccountConfig } from "../../shared/account-config.js";
import type {
  FeishuConfig,
  FeishuAccountConfig,
  FeishuDomain,
  ResolvedFeishuAccount,
} from "./types.js";

const {
  listAccountIds: listFeishuAccountIds,
  resolveDefaultAccountId: resolveDefaultFeishuAccountId,
} = createAccountListHelpers("feishu");

export { listFeishuAccountIds, resolveDefaultFeishuAccountId };

function mergeFeishuAccountConfig(cfg: ClawdbotConfig, accountId: string): FeishuConfig {
  return mergeChannelAccountConfig<FeishuConfig>(cfg, "feishu", accountId);
}

/**
 * Resolve Feishu credentials from a config.
 */
export function resolveFeishuCredentials(cfg?: FeishuConfig): {
  appId: string;
  appSecret: string;
  encryptKey?: string;
  verificationToken?: string;
  domain: FeishuDomain;
} | null {
  const appId = cfg?.appId?.trim();
  const appSecret = cfg?.appSecret?.trim();
  if (!appId || !appSecret) {
    return null;
  }
  return {
    appId,
    appSecret,
    encryptKey: cfg?.encryptKey?.trim() || undefined,
    verificationToken: cfg?.verificationToken?.trim() || undefined,
    domain: cfg?.domain ?? "feishu",
  };
}

export function resolveFeishuAccount(params: {
  cfg: ClawdbotConfig;
  accountId?: string | null;
}): ResolvedFeishuAccount {
  const accountId = normalizeAccountId(params.accountId);
  const feishuCfg = params.cfg.channels?.feishu as FeishuConfig | undefined;
  const baseEnabled = feishuCfg?.enabled !== false;
  const merged = mergeFeishuAccountConfig(params.cfg, accountId);
  const accountEnabled = merged.enabled !== false;
  const enabled = baseEnabled && accountEnabled;
  const creds = resolveFeishuCredentials(merged);

  return {
    accountId,
    enabled,
    configured: Boolean(creds),
    name: (merged as FeishuAccountConfig).name?.trim() || undefined,
    appId: creds?.appId,
    appSecret: creds?.appSecret,
    encryptKey: creds?.encryptKey,
    verificationToken: creds?.verificationToken,
    domain: creds?.domain ?? "feishu",
    config: merged,
  };
}

export function listEnabledFeishuAccounts(cfg: ClawdbotConfig): ResolvedFeishuAccount[] {
  return listFeishuAccountIds(cfg)
    .map((accountId) => resolveFeishuAccount({ cfg, accountId }))
    .filter((account) => account.enabled && account.configured);
}
