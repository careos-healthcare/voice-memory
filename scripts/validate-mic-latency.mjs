#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const vuln = fs.readFileSync(path.join(ROOT, "packages/shared/lib/capture/vulnerability-timing.ts"), "utf8");
for (const token of [
  "app_open_to_mic_visible_ms",
  "app_open_to_recording_started_ms",
  "markMicVisible",
  "useLayoutEffect",
]) {
  if (token === "useLayoutEffect") {
    const shell = fs.readFileSync(
      path.join(ROOT, "apps/web/components/capture/ZeroStateRecorderShell.tsx"),
      "utf8",
    );
    if (!shell.includes("useLayoutEffect")) {
      failures.push("ZeroStateRecorderShell must mark mic visible in useLayoutEffect");
    }
    continue;
  }
  if (!vuln.includes(token)) failures.push(`vulnerability-timing missing ${token}`);
}

const hesitation = fs.readFileSync(path.join(ROOT, "packages/shared/lib/capture/hesitation-signals.ts"), "utf8");
if (!hesitation.includes("markMicVisibleForHesitation") || !hesitation.includes("markSpeechStartedAfterHesitation")) {
  failures.push("hesitation-signals must track silence-before-speech");
}

const types = fs.readFileSync(path.join(ROOT, "packages/shared/types/vulnerability-timing.ts"), "utf8");
if (!types.includes("medianAppOpenToMicVisibleMs")) {
  failures.push("vulnerability timing types must include app-open latency fields");
}

if (failures.length > 0) {
  console.error("validate-mic-latency failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-mic-latency ok");
