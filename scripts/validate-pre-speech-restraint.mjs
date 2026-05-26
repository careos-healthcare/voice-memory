#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const failures = [];

const restraint = fs.readFileSync(
  path.join(ROOT, "lib/capture/pre-speech-restraint.ts"),
  "utf8",
);
for (const fn of [
  "capPreSpeechSurfaces",
  "shouldHideBeforeSpeaking",
  "assertMicCentralityBeforeSpeech",
]) {
  if (!restraint.includes(fn)) failures.push(`pre-speech-restraint missing ${fn}`);
}

const shell = fs.readFileSync(
  path.join(ROOT, "components/capture/ZeroStateRecorderShell.tsx"),
  "utf8",
);
const lineCount = (shell.match(/<p className=/g) ?? []).length;
if (lineCount > 1) {
  failures.push("ZeroStateRecorderShell has more than one pre-speech line");
}

const recorder = fs.readFileSync(path.join(ROOT, "components/Recorder.tsx"), "utf8");
if (!recorder.includes("zeroState")) {
  failures.push("Recorder must support zeroState prop");
}

if (failures.length > 0) {
  console.error("validate-pre-speech-restraint failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-pre-speech-restraint ok");
