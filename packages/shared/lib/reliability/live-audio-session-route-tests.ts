import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

import { buildProxyWebSocketUrl } from "@/lib/live-audio/proxy-url";
import { GeminiLiveProxy } from "@/lib/live-audio/gemini-live-proxy";
import { buildLiveSetupMessage } from "@/lib/live-audio/protocol";
import {
  signLiveAudioSessionToken,
  verifyLiveAudioSessionToken,
} from "@/lib/live-audio/session-token";
import {
  consumeLiveAudioSession,
  registerLiveAudioSession,
  resetLiveAudioSessionStoreForTest,
} from "@/lib/live-audio/session-store";
import { resetLiveAudioUsageForTest } from "@/lib/live-audio/usage-limits";

const ROUTE_PATH = path.join(process.cwd(), "apps/api/app/api/live-audio/session/route.ts");

function readRouteSource(): string {
  return fs.readFileSync(ROUTE_PATH, "utf8");
}

export async function runLiveAudioSessionRouteTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];

  function check(name: string, fn: () => void | Promise<void>): Promise<void> {
    return Promise.resolve()
      .then(fn)
      .catch((error) => {
        failures.push(`${name}: ${error instanceof Error ? error.message : String(error)}`);
      });
  }

  await check("session route exports GET and POST handlers", () => {
    const source = readRouteSource();
    assert.match(source, /export async function GET/);
    assert.match(source, /export async function POST/);
    assert.match(source, /guardLiveAudioSessionRoute/);
    assert.match(source, /sessionToken/);
    assert.doesNotMatch(source, /sessionToken:\s*process\.env\.GEMINI_API_KEY/);
    assert.doesNotMatch(source, /GEMINI_API_KEY\s*[,}]/);
  });

  await check("live session token signs and verifies with binding", () => {
    const binding = { ipHash: "ip_test", uaHash: "ua_test" };
    const { token, payload } = signLiveAudioSessionToken("device:test", binding);
    const verified = verifyLiveAudioSessionToken(token, binding);
    assert.ok(verified);
    assert.equal(verified?.sessionId, payload.sessionId);
    assert.equal(verified?.subject, "device:test");
  });

  await check("live session token rejects binding mismatch", () => {
    const { token } = signLiveAudioSessionToken("device:test", {
      ipHash: "ip_a",
      uaHash: "ua_a",
    });
    assert.equal(
      verifyLiveAudioSessionToken(token, { ipHash: "ip_b", uaHash: "ua_b" }),
      null,
    );
  });

  await check("live session store consumes a registered session once", async () => {
    resetLiveAudioSessionStoreForTest();
    const binding = { ipHash: "ip_store", uaHash: "ua_store" };
    const { payload } = signLiveAudioSessionToken("device:store", binding);
    await registerLiveAudioSession({
      jti: payload.jti,
      sessionId: payload.sessionId,
      subject: payload.subject,
      ipHash: binding.ipHash,
      uaHash: binding.uaHash,
    });

    const first = await consumeLiveAudioSession({
      jti: payload.jti,
      ipHash: binding.ipHash,
      uaHash: binding.uaHash,
    });
    assert.equal(first.ok, true);

    const second = await consumeLiveAudioSession({
      jti: payload.jti,
      ipHash: binding.ipHash,
      uaHash: binding.uaHash,
    });
    assert.equal(second.ok, false);
    if (!second.ok) {
      assert.equal(second.reason, "consumed");
    }
  });

  await check("session mint route returns ws proxy url helper", () => {
    assert.equal(
      buildProxyWebSocketUrl("http://127.0.0.1:3000"),
      "ws://127.0.0.1:3000/api/live-audio/ws",
    );
    assert.equal(
      buildProxyWebSocketUrl("https://api.example.com"),
      "wss://api.example.com/api/live-audio/ws",
    );
    const source = readRouteSource();
    assert.match(source, /buildProxyWebSocketUrl/);
  });

  await check("GeminiLiveProxy sends setup frame on connect", async () => {
    const sent: string[] = [];
    const proxy = new GeminiLiveProxy({
      apiKey: "test-key",
      connectWebSocket: async () => ({
        send(data) {
          sent.push(data);
        },
        close() {},
        onMessage() {},
        onError() {},
        onClose() {},
      }),
    });

    await proxy.connect({
      onServerEvents() {},
    });

    assert.equal(sent.length, 1);
    assert.deepEqual(JSON.parse(sent[0] ?? "{}"), buildLiveSetupMessage());
    assert.equal(proxy.state, "awaiting_setup_complete");
  });

  await check("GeminiLiveProxy blocks client relay before setupComplete", async () => {
    const proxy = new GeminiLiveProxy({
      apiKey: "test-key",
      connectWebSocket: async () => ({
        send() {},
        close() {},
        onMessage() {},
        onError() {},
        onClose() {},
      }),
    });

    await proxy.connect({ onServerEvents() {} });
    const result = proxy.relayClientJson(
      JSON.stringify(buildLiveSetupMessage()),
    );
    assert.equal(result.ok, false);
    if (!result.ok) {
      assert.equal(result.reason, "awaiting_setup_complete");
    }
  });

  resetLiveAudioUsageForTest();
  resetLiveAudioSessionStoreForTest();

  return { failures };
}
