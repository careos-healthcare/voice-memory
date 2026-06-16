#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

for (const rel of [
  "lib/server/api-guard.ts",
  "lib/server/openai-budget-guard.ts",
  "lib/server/openai-cost-estimator.ts",
  "lib/server/openai-spend-store.ts",
  "lib/server/capture-auth-crypto.ts",
  "lib/server/api-usage-store.ts",
  "app/api/capture/attest/route.ts",
  "lib/client/capture-attest.ts",
]) {
  if (!fs.existsSync(path.join(ROOT, rel))) failures.push(`missing ${rel}`);
}

const transcribe = fs.readFileSync(path.join(ROOT, "app/api/transcribe/route.ts"), "utf8");
const analyze = fs.readFileSync(path.join(ROOT, "app/api/analyze/route.ts"), "utf8");

if (!transcribe.includes("guardOpenAiRoute")) {
  failures.push("transcribe must use guardOpenAiRoute");
}
if (!analyze.includes("guardOpenAiRoute")) {
  failures.push("analyze must use guardOpenAiRoute");
}

const atmosphere = fs.readFileSync(path.join(ROOT, "app/api/atmosphere/route.ts"), "utf8");
if (!atmosphere.includes("guardOpenAiRoute")) {
  failures.push("atmosphere must use guardOpenAiRoute");
}
if (!transcribe.includes("MAX_AUDIO_BYTES")) {
  failures.push("transcribe must enforce audio size limit");
}

const recorder = fs.readFileSync(path.join(ROOT, "components/Recorder.tsx"), "utf8");
if (!recorder.includes("ensureCaptureAttested")) {
  failures.push("Recorder must attest before OpenAI routes");
}

if (failures.length > 0) {
  console.error("validate-api-guard failed:\n", failures.join("\n"));
  process.exit(1);
}

const blockers = spawnSync("npm", ["run", "validate:grade-a-blockers-tests"], {
  cwd: ROOT,
  stdio: "inherit",
  env: process.env,
});
if (blockers.status !== 0) {
  process.exit(blockers.status ?? 1);
}

console.log("validate-api-guard ok (static + grade-a-blockers-tests)");
