#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const offline = fs.readFileSync(
  path.join(ROOT, "lib/reliability/offline-transcription.ts"),
  "utf8",
);
if (!offline.includes("Saved on this device. Transcription needs internet.")) {
  failures.push("offline-transcription must use calm saved copy");
}

const recorder = fs.readFileSync(path.join(ROOT, "components/Recorder.tsx"), "utf8");
if (recorder.includes("Failed to fetch")) {
  failures.push("Recorder must not show raw Failed to fetch");
}
if (!recorder.includes("OFFLINE_TRANSCRIPTION_SAVED_COPY") || !recorder.includes("saveOfflineRecordingDraft")) {
  failures.push("Recorder must wire offline transcription fallback");
}

const mic = fs.readFileSync(path.join(ROOT, "lib/capture/mic-permission-copy.ts"), "utf8");
if (!mic.includes("Allow microphone to record here")) {
  failures.push("mic-permission-copy must include allow line");
}
if (!recorder.includes("MicPermissionPanel")) {
  failures.push("Recorder must use MicPermissionPanel");
}

if (failures.length > 0) {
  console.error("validate-offline-recording-copy failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-offline-recording-copy ok");
