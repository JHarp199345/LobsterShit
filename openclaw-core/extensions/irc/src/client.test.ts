import { describe, expect, it } from "vitest";
import { buildIrcNickServCommands } from "./client.js";

const MOCK_PW = process.env.TEST_IRC_PASSWORD ?? "x";

describe("irc client nickserv", () => {
  it("builds IDENTIFY command when password is set", () => {
    expect(
      buildIrcNickServCommands({
        password: MOCK_PW,
      }),
    ).toEqual([`PRIVMSG NickServ :IDENTIFY ${MOCK_PW}`]);
  });

  it("builds REGISTER command when enabled with email", () => {
    expect(
      buildIrcNickServCommands({
        password: MOCK_PW,
        register: true,
        registerEmail: "bot@example.com",
      }),
    ).toEqual([
      `PRIVMSG NickServ :IDENTIFY ${MOCK_PW}`,
      `PRIVMSG NickServ :REGISTER ${MOCK_PW} bot@example.com`,
    ]);
  });

  it("rejects register without registerEmail", () => {
    expect(() =>
      buildIrcNickServCommands({
        password: MOCK_PW,
        register: true,
      }),
    ).toThrow(/registerEmail/);
  });

  it("sanitizes outbound NickServ payloads", () => {
    const pwWithNewline = `${MOCK_PW}\r\nJOIN #bad`;
    expect(
      buildIrcNickServCommands({
        service: "NickServ\n",
        password: pwWithNewline,
      }),
    ).toEqual([`PRIVMSG NickServ :IDENTIFY ${MOCK_PW} JOIN #bad`]);
  });
});
