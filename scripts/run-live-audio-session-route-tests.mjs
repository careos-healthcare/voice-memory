#!/usr/bin/env node
import { runLiveAudioSessionRouteTests } from "../lib/reliability/live-audio-session-route-tests.ts";

const { failures } = await runLiveAudioSessionRouteTests();

if (failures.length) {
  console.error("validate-live-audio-session failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-live-audio-session ok");
