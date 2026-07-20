import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

import { buildLiveAudioInputMessage } from "@/lib/live-audio/protocol";
import {
  signLiveAudioSessionToken,
} from "@/lib/live-audio/session-token";
import {
  registerLiveAudioSession,
  resetLiveAudioSessionStoreForTest,
} from "@/lib/live-audio/session-store";
import { authenticateLiveAudioWebSocketRequest } from "@/lib/live-audio/ws-auth";
import {
  runLiveAudioProxyConnection,
  type LiveAudioClientSocket,
} from "@/lib/live-audio/ws-proxy-connection";
import { GeminiLiveProxy } from "@/lib/live-audio/gemini-live-proxy";

const WS_ROUTE_PATH = path.join(process.cwd(), "app/api/live-audio/ws/route.ts");
const WS_UPGRADE_PATH = path.join(process.cwd(), "lib/live-audio/ws-upgrade.ts");
const SERVER_ENTRY_PATH = path.join(process.cwd(), "server.entry.ts");
const SERVER_BUNDLE_PATH = path.join(process.cwd(), "dist/main.js");

function readSource(filePath: string): string {
  return fs.readFileSync(filePath, "utf8");
}

function createMockClient(): LiveAudioClientSocket & {
  sent: string[];
  messageHandler: ((data: string) => void) | null;
} {
  const sent: string[] = [];
  let messageHandler: ((data: string) => void) | null = null;
  return {
    sent,
    messageHandler,
    send(data) {
      sent.push(data);
    },
    close() {},
    onMessage(handler) {
      messageHandler = handler;
      this.messageHandler = handler;
    },
    onClose() {},
    onError() {},
  };
}

export async function runLiveAudioWsRouteTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];

  function check(name: string, fn: () => void | Promise<void>): Promise<void> {
    return Promise.resolve()
      .then(fn)
      .catch((error) => {
        failures.push(`${name}: ${error instanceof Error ? error.message : String(error)}`);
      });
  }

  await check("ws route and upgrade files exist without exposing GEMINI_API_KEY", () => {
    const routeSource = readSource(WS_ROUTE_PATH);
    const upgradeSource = readSource(WS_UPGRADE_PATH);
    const serverEntrySource = readSource(SERVER_ENTRY_PATH);

    assert.match(routeSource, /LIVE_AUDIO_PROXY_WS_PATH/);
    assert.match(routeSource, /sessionTokenQueryParam/);
    assert.match(upgradeSource, /attachLiveAudioWebSocketUpgrade/);
    assert.match(upgradeSource, /authenticateLiveAudioWebSocketUpgrade/);
    assert.match(upgradeSource, /runLiveAudioProxyConnection/);
    assert.match(serverEntrySource, /attachLiveAudioWebSocketUpgrade/);
    if (fs.existsSync(SERVER_BUNDLE_PATH)) {
      assert.match(readSource(SERVER_BUNDLE_PATH), /attachLiveAudioWebSocketUpgrade/);
    }
    assert.doesNotMatch(routeSource, /GEMINI_API_KEY/);
    assert.doesNotMatch(upgradeSource, /GEMINI_API_KEY\s*[,}]/);
  });

  await check("ws auth accepts a minted session token once", async () => {
    resetLiveAudioSessionStoreForTest();
    const binding = { ipHash: "ip_ws", uaHash: "ua_ws" };
    const { token, payload } = signLiveAudioSessionToken("device:ws", binding);
    await registerLiveAudioSession({
      jti: payload.jti,
      sessionId: payload.sessionId,
      subject: payload.subject,
      ipHash: binding.ipHash,
      uaHash: binding.uaHash,
    });

    const first = await authenticateLiveAudioWebSocketRequest({
      query: { sessionToken: token },
      ipHash: binding.ipHash,
      uaHash: binding.uaHash,
      isGeminiConfigured: () => true,
      isGeminiKillSwitchActive: () => false,
    });
    assert.equal(first.ok, true);
    if (first.ok) {
      assert.equal(first.sessionId, payload.sessionId);
    }

    const second = await authenticateLiveAudioWebSocketRequest({
      query: { sessionToken: token },
      ipHash: binding.ipHash,
      uaHash: binding.uaHash,
      isGeminiConfigured: () => true,
      isGeminiKillSwitchActive: () => false,
    });
    assert.equal(second.ok, false);
    if (!second.ok) {
      assert.equal(second.code, "SESSION_NOT_AVAILABLE");
    }
  });

  await check("ws auth rejects missing session token", async () => {
    const result = await authenticateLiveAudioWebSocketRequest({
      query: {},
      ipHash: "ip",
      uaHash: "ua",
      isGeminiConfigured: () => true,
      isGeminiKillSwitchActive: () => false,
    });
    assert.equal(result.ok, false);
    if (!result.ok) {
      assert.equal(result.code, "MISSING_SESSION_TOKEN");
    }
  });

  await check("proxy connection forwards upstream frames and relays PCM after setupComplete", async () => {
    const client = createMockClient();
    const upstreamSent: string[] = [];
    let upstreamMessageHandler: ((raw: string) => void) | null = null;

    const proxy = new GeminiLiveProxy({
      apiKey: "test-key",
      connectWebSocket: async () => ({
        send(data) {
          upstreamSent.push(data);
        },
        close() {},
        onMessage(handler) {
          upstreamMessageHandler = handler;
        },
        onError() {},
        onClose() {},
      }),
    });

    await runLiveAudioProxyConnection({
      client,
      sessionId: "session_proxy",
      subject: "device:proxy",
      apiKey: "test-key",
      createProxy: () => proxy,
    });

    assert.equal(upstreamSent.length, 1);
    upstreamMessageHandler?.(JSON.stringify({ setupComplete: {} }));

    const audioFrame = JSON.stringify(buildLiveAudioInputMessage(Buffer.from([1, 2, 3, 4])));
    client.messageHandler?.(audioFrame);
    assert.equal(upstreamSent.length, 2);
    assert.match(upstreamSent[1] ?? "", /realtimeInput/);
    assert.match(upstreamSent[1] ?? "", /audio\/pcm;rate=16000/);
  });

  await check("proxy connection rejects client setup frames", async () => {
    const client = createMockClient();
    await runLiveAudioProxyConnection({
      client,
      sessionId: "session_setup_reject",
      subject: "device:setup",
      apiKey: "test-key",
      createProxy: () =>
        new GeminiLiveProxy({
          apiKey: "test-key",
          connectWebSocket: async () => ({
            send() {},
            close() {},
            onMessage() {},
            onError() {},
            onClose() {},
          }),
        }),
    });

    client.messageHandler?.(
      JSON.stringify({
        setup: { model: "models/gemini-2.5-flash-exp" },
      }),
    );

    assert.equal(client.sent.some((frame) => frame.includes("client_setup_not_allowed")), true);
  });

  resetLiveAudioSessionStoreForTest();

  return { failures };
}
