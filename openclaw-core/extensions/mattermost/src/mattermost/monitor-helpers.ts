import {
  formatInboundFromLabel as formatInboundFromLabelShared,
  resolveThreadSessionKeys as resolveThreadSessionKeysShared,
  type OpenClawConfig,
} from "openclaw/plugin-sdk";
import { sanitizeForIdentifier } from "../../../shared/identifiers.js";
export { createDedupeCache, rawDataToString } from "openclaw/plugin-sdk";

export type ResponsePrefixContext = {
  model?: string;
  modelFull?: string;
  provider?: string;
  thinkingLevel?: string;
  identityName?: string;
};

export function extractShortModelName(fullModel: string): string {
  const slash = fullModel.lastIndexOf("/");
  const modelPart = slash >= 0 ? fullModel.slice(slash + 1) : fullModel;
  return modelPart.replace(/-\d{8}$/, "").replace(/-latest$/, "");
}

export const formatInboundFromLabel = formatInboundFromLabelShared;

function normalizeAgentId(value: string | undefined | null): string {
  return sanitizeForIdentifier(value, {
    replaceChar: "-",
    maxLen: 64,
    default: "main",
    allowDots: false,
  });
}

type AgentEntry = NonNullable<NonNullable<OpenClawConfig["agents"]>["list"]>[number];

function listAgents(cfg: OpenClawConfig): AgentEntry[] {
  const list = cfg.agents?.list;
  if (!Array.isArray(list)) {
    return [];
  }
  return list.filter((entry): entry is AgentEntry => Boolean(entry && typeof entry === "object"));
}

function resolveAgentEntry(cfg: OpenClawConfig, agentId: string): AgentEntry | undefined {
  const id = normalizeAgentId(agentId);
  return listAgents(cfg).find((entry) => normalizeAgentId(entry.id) === id);
}

export function resolveIdentityName(cfg: OpenClawConfig, agentId: string): string | undefined {
  const entry = resolveAgentEntry(cfg, agentId);
  return entry?.identity?.name?.trim() || undefined;
}

export function resolveThreadSessionKeys(params: {
  baseSessionKey: string;
  threadId?: string | null;
  parentSessionKey?: string;
  useSuffix?: boolean;
}): { sessionKey: string; parentSessionKey?: string } {
  return resolveThreadSessionKeysShared({
    ...params,
    normalizeThreadId: (threadId) => threadId,
  });
}
