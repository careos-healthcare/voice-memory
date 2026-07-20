import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

import {
  activeLiveAudioConnectionCount,
  beginLiveAudioDrain,
  broadcastCoordinatorDisconnect,
  forceCloseRemainingLiveAudioConnections,
  isLiveAudioDraining,
  LIVE_AUDIO_COORDINATOR_DISCONNECT,
  registerLiveAudioConnection,
  resetLiveAudioConnectionRegistryForTest,
} from "@/lib/live-audio/live-audio-connection-registry";
import {
  GRACEFUL_SHUTDOWN_DRAIN_MS,
  resetGracefulShutdownForTest,
  runGracefulShutdown,
} from "@/lib/server/graceful-shutdown";

function readSource(relativePath: string): string {
  return fs.readFileSync(path.join(process.cwd(), relativePath), "utf8");
}

function createMockClient() {
  const sent: string[] = [];
  let closeCode: number | undefined;
  let closeReason: string | undefined;

  return {
    sent,
    client: {
      send(data: string) {
        sent.push(data);
      },
      close(code?: number, reason?: string) {
        closeCode = code;
        closeReason = reason;
      },
      onMessage() {},
      onClose() {},
      onError() {},
    },
    ws: {
      terminate() {},
    },
    closeCode: () => closeCode,
    closeReason: () => closeReason,
  };
}

export async function runLiveAudioGracefulShutdownTests(): Promise<{
  failures: string[];
}> {
  const failures: string[] = [];

  function check(name: string, fn: () => void | Promise<void>): Promise<void> {
    return Promise.resolve()
      .then(fn)
      .catch((error) => {
        failures.push(
          `${name}: ${error instanceof Error ? error.message : String(error)}`,
        );
      });
  }

  await check("healthz route stays shallow and avoids database probes", () => {
    const source = readSource("app/api/healthz/route.ts");
    assert.match(source, /status:\s*"ok"/);
    assert.doesNotMatch(source, /verifyMigrations/);
    assert.doesNotMatch(source, /hasDatabaseUrl/);
    assert.doesNotMatch(source, /DATABASE_URL/);
  });

  await check("server entry registers SIGTERM graceful shutdown", () => {
    const source = readSource("server.entry.ts");
    assert.match(source, /registerGracefulShutdown/);
    const shutdownSource = readSource("lib/server/graceful-shutdown.ts");
    assert.match(shutdownSource, /SIGTERM/);
    assert.match(shutdownSource, /broadcastCoordinatorDisconnect/);
    assert.equal(GRACEFUL_SHUTDOWN_DRAIN_MS, 10_000);
  });

  await check("ws upgrade rejects new streams while draining", () => {
    const source = readSource("lib/live-audio/ws-upgrade.ts");
    assert.match(source, /isLiveAudioDraining\(\)/);
    assert.match(source, /503/);
    assert.match(source, /LIVE_AUDIO_COORDINATOR_DISCONNECT/);
  });

  await check(
    "drain broadcasts coordinator_disconnect before forced close",
    () => {
      resetLiveAudioConnectionRegistryForTest();
      const mock = createMockClient();
      const unregister = registerLiveAudioConnection({
        sessionId: "session_drain",
        client: mock.client,
        ws: mock.ws as never,
      });

      beginLiveAudioDrain();
      assert.equal(isLiveAudioDraining(), true);
      assert.equal(broadcastCoordinatorDisconnect(), 1);
      assert.match(mock.sent[0] ?? "", /coordinator_disconnect/);
      assert.equal(mock.closeReason(), LIVE_AUDIO_COORDINATOR_DISCONNECT);
      assert.equal(mock.closeCode(), 1001);

      unregister();
      assert.equal(activeLiveAudioConnectionCount(), 0);
      resetLiveAudioConnectionRegistryForTest();
    },
  );

  await check("graceful shutdown waits full drain window before exit", async () => {
    resetLiveAudioConnectionRegistryForTest();
    resetGracefulShutdownForTest();

    const previousDrainMs = process.env.VOICEMEMORY_GRACEFUL_SHUTDOWN_DRAIN_MS;
    process.env.VOICEMEMORY_GRACEFUL_SHUTDOWN_DRAIN_MS = "50";

    const mock = createMockClient();
    registerLiveAudioConnection({
      sessionId: "session_shutdown",
      client: mock.client,
      ws: mock.ws as never,
    });

    let exitCode: number | null = null;
    const originalExit = process.exit;
    process.exit = ((code?: number) => {
      exitCode = code ?? 0;
    }) as typeof process.exit;

    const started = Date.now();
    try {
      await runGracefulShutdown(
        {
          close(callback) {
            callback?.();
          },
        } as import("node:http").Server,
        "SIGTERM",
      );
      assert.ok(Date.now() - started >= 40);
    } finally {
      process.exit = originalExit;
      if (previousDrainMs === undefined) {
        delete process.env.VOICEMEMORY_GRACEFUL_SHUTDOWN_DRAIN_MS;
      } else {
        process.env.VOICEMEMORY_GRACEFUL_SHUTDOWN_DRAIN_MS = previousDrainMs;
      }
      resetGracefulShutdownForTest();
      resetLiveAudioConnectionRegistryForTest();
    }

    assert.equal(exitCode, 0);
    assert.match(mock.sent[0] ?? "", /coordinator_disconnect/);
    assert.equal(forceCloseRemainingLiveAudioConnections(), 0);
  });

  return { failures };
}
