#!/usr/bin/env node
import { runLiveAudioWsRouteTests } from "../lib/reliability/live-audio-ws-route-tests.ts";

const ws = await runLiveAudioWsRouteTests();
const { runLiveAudioGracefulShutdownTests } = await import(
  "../lib/reliability/live-audio-graceful-shutdown-tests.ts"
);
const shutdown = await runLiveAudioGracefulShutdownTests();

const failures = [...ws.failures, ...shutdown.failures];

if (failures.length) {
  console.error("validate-live-audio-ws failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-live-audio-ws ok");
