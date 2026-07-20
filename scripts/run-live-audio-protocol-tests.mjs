#!/usr/bin/env node
import { runLiveAudioProtocolTests } from "../lib/reliability/live-audio-protocol-tests.ts";

const { failures } = await runLiveAudioProtocolTests();

if (failures.length) {
  console.error("validate-live-audio-protocol failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-live-audio-protocol ok");
