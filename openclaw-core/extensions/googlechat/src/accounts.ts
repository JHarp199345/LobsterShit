import type { OpenClawConfig } from "openclaw/plugin-sdk";
import { createAccountListHelpers } from "openclaw/plugin-sdk";
import { DEFAULT_ACCOUNT_ID, normalizeAccountId } from "openclaw/plugin-sdk/account-id";
import { mergeChannelAccountConfig } from "../../shared/account-config.js";
import type { GoogleChatAccountConfig } from "./types.config.js";

export type GoogleChatCredentialSource = "file" | "inline" | "env" | "none";

export type ResolvedGoogleChatAccount = {
  accountId: string;
  name?: string;
  enabled: boolean;
  config: GoogleChatAccountConfig;
  credentialSource: GoogleChatCredentialSource;
  credentials?: Record<string, unknown>;
  credentialsFile?: string;
};

const ENV_SERVICE_ACCOUNT = "GOOGLE_CHAT_SERVICE_ACCOUNT";
const ENV_SERVICE_ACCOUNT_FILE = "GOOGLE_CHAT_SERVICE_ACCOUNT_FILE";

const { listAccountIds, resolveDefaultAccountId } = createAccountListHelpers("googlechat");

export const listGoogleChatAccountIds = listAccountIds;

export function resolveDefaultGoogleChatAccountId(cfg: OpenClawConfig): string {
  const defaultAccount = (
    cfg.channels?.["googlechat"] as { defaultAccount?: string } | undefined
  )?.defaultAccount?.trim();
  if (defaultAccount) return defaultAccount;
  return resolveDefaultAccountId(cfg);
}

function mergeGoogleChatAccountConfig(
  cfg: OpenClawConfig,
  accountId: string,
): GoogleChatAccountConfig {
  return mergeChannelAccountConfig<GoogleChatAccountConfig>(cfg, "googlechat", accountId, [
    "defaultAccount",
  ]);
}

function parseServiceAccount(value: unknown): Record<string, unknown> | null {
  if (value && typeof value === "object") {
    return value as Record<string, unknown>;
  }
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  if (!trimmed) {
    return null;
  }
  try {
    return JSON.parse(trimmed) as Record<string, unknown>;
  } catch {
    return null;
  }
}

function resolveCredentialsFromConfig(params: {
  accountId: string;
  account: GoogleChatAccountConfig;
}): {
  credentials?: Record<string, unknown>;
  credentialsFile?: string;
  source: GoogleChatCredentialSource;
} {
  const { account, accountId } = params;
  const inline = parseServiceAccount(account.serviceAccount);
  if (inline) {
    return { credentials: inline, source: "inline" };
  }

  const file = account.serviceAccountFile?.trim();
  if (file) {
    return { credentialsFile: file, source: "file" };
  }

  if (accountId === DEFAULT_ACCOUNT_ID) {
    const envJson = process.env[ENV_SERVICE_ACCOUNT];
    const envInline = parseServiceAccount(envJson);
    if (envInline) {
      return { credentials: envInline, source: "env" };
    }
    const envFile = process.env[ENV_SERVICE_ACCOUNT_FILE]?.trim();
    if (envFile) {
      return { credentialsFile: envFile, source: "env" };
    }
  }

  return { source: "none" };
}

export function resolveGoogleChatAccount(params: {
  cfg: OpenClawConfig;
  accountId?: string | null;
}): ResolvedGoogleChatAccount {
  const accountId = normalizeAccountId(params.accountId);
  const baseEnabled = params.cfg.channels?.["googlechat"]?.enabled !== false;
  const merged = mergeGoogleChatAccountConfig(params.cfg, accountId);
  const accountEnabled = merged.enabled !== false;
  const enabled = baseEnabled && accountEnabled;
  const credentials = resolveCredentialsFromConfig({ accountId, account: merged });

  return {
    accountId,
    name: merged.name?.trim() || undefined,
    enabled,
    config: merged,
    credentialSource: credentials.source,
    credentials: credentials.credentials,
    credentialsFile: credentials.credentialsFile,
  };
}

export function listEnabledGoogleChatAccounts(cfg: OpenClawConfig): ResolvedGoogleChatAccount[] {
  return listGoogleChatAccountIds(cfg)
    .map((accountId) => resolveGoogleChatAccount({ cfg, accountId }))
    .filter((account) => account.enabled);
}
