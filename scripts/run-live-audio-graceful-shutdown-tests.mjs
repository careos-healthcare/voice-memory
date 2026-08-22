#!/usr/bin/env node
import { runLiveAudioGracefulShutdownTests } from "../packages/shared/lib/reliability/live-audio-graceful-shutdown-tests.ts";

const { failures } = await runLiveAudioGracefulShutdownTests();

if (failures.length) {
  console.error("validate-live-audio-graceful-shutdown failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-live-audio-graceful-shutdown ok");
