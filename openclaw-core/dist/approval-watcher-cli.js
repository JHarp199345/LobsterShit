/**
 * CLI Approval Watcher - Aider-style approval prompts in the terminal.
 * Run in a split pane alongside the TUI for instant approval feedback.
 */
import { createInterface } from "node:readline";
import { randomUUID } from "node:crypto";
import { t as GatewayClient, $t as loadOrCreateDeviceIdentity, At as PROTOCOL_VERSION } from "./client-EwxHy0Jk.js";
import { t as buildGatewayConnectionDetails, o as resolveExplicitGatewayAuth } from "./call-Dx-c0m2G.js";
import { Rt as loadConfig } from "./model-selection-J6oFwo9y.js";
import { h as GATEWAY_CLIENT_NAMES, m as GATEWAY_CLIENT_MODES } from "./message-channel-BFAJAoI_.js";
import { t as resolveGatewayCredentialsFromConfig } from "./credentials-xxcK5iF5.js";
import { g as resolveStateDir, o as resolveConfigPath } from "./paths-B4BZAPZh.js";

const BOLD_RED = "\x1b[1;31m";
const RESET = "\x1b[0m";

function prompt(question) {
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer?.trim().toLowerCase());
    });
  });
}

function runApprovalWatcher() {
  const config = loadConfig();
  const configPath = resolveConfigPath(process.env, resolveStateDir(process.env));
  const connectionDetails = buildGatewayConnectionDetails({ config, configPath });
  const { token, password } = resolveGatewayCredentialsFromConfig({
    cfg: config,
    env: process.env,
    explicitAuth: resolveExplicitGatewayAuth({ token: undefined, password: undefined }),
    urlOverride: undefined,
    remotePasswordPrecedence: "env-first",
  });

  const client = new GatewayClient({
    url: connectionDetails.url,
    token,
    password,
    clientName: GATEWAY_CLIENT_NAMES.CLI,
    clientDisplayName: "approval-watcher",
    clientVersion: "1.0.0",
    platform: process.platform,
    mode: GATEWAY_CLIENT_MODES.CLI,
    role: "operator",
    scopes: ["operator.approvals"],
    deviceIdentity: loadOrCreateDeviceIdentity(),
    minProtocol: PROTOCOL_VERSION,
    maxProtocol: PROTOCOL_VERSION,
    instanceId: randomUUID(),
    onHelloOk: () => {
      console.error("[approval-watcher] Connected. Waiting for exec approval requests...\n");
    },
    onEvent: async (evt) => {
      if (evt.event !== "exec.approval.requested") return;
      const { id, request } = evt.payload ?? {};
      if (!id || !request) return;

      const cmd = request.command ?? (Array.isArray(request.commandArgv) ? request.commandArgv.join(" ") : "(no command)");
      console.error("\n" + BOLD_RED + "═══ EXEC APPROVAL REQUESTED ═══" + RESET);
      console.error(BOLD_RED + cmd + RESET);
      console.error("");

      const answer = await prompt("APPROVE? (y/n/a=allow-always): ");
      const decision = answer === "a" || answer === "allow-always" ? "allow-always" : answer === "y" || answer === "yes" ? "allow-once" : "deny";

      try {
        await client.request("exec.approval.resolve", { id, decision });
        console.error(`[approval-watcher] Resolved ${id} with ${decision}\n`);
      } catch (err) {
        console.error(`[approval-watcher] Resolve failed: ${err?.message ?? err}\n`);
      }
    },
    onClose: (code, reason) => {
      console.error(`[approval-watcher] Disconnected (${code}): ${reason}`);
    },
    onConnectError: (err) => {
      console.error(`[approval-watcher] Connect failed: ${err?.message ?? err}`);
      process.exit(1);
    },
  });

  client.start();

  process.on("SIGINT", () => {
    client.stop();
    process.exit(0);
  });
}

export function registerApprovalWatcherCli(program) {
  program
    .command("approval-watch")
    .description("Watch for exec approval requests and prompt in CLI (run in split pane with TUI)")
    .action(() => {
      runApprovalWatcher();
    });
}
