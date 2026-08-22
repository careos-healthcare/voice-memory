#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const manifest = JSON.parse(
  fs.readFileSync(
    path.join(ROOT, "packages/shared/lib/server/active-api-routes-manifest.json"),
    "utf8",
  ),
);
const failures = [];

function assertRouteFile(relPath, guardName) {
  const absolute = path.join(ROOT, relPath);
  if (!fs.existsSync(absolute)) {
    failures.push(
      `stale validator target: ${relPath} is listed in active-api-routes-manifest but missing on disk`,
    );
    return;
  }
  const text = fs.readFileSync(absolute, "utf8");
  if (!text.includes(guardName)) {
    failures.push(`${relPath} must use ${guardName}`);
  }
}

for (const rel of manifest.apiGuardSupportFiles) {
  if (!fs.existsSync(path.join(ROOT, rel))) {
    failures.push(`missing support file ${rel}`);
  }
}

for (const route of manifest.guardedOpenAi) {
  assertRouteFile(route.routeFile, route.guard);
}

for (const route of manifest.guardedAttest) {
  assertRouteFile(route.routeFile, route.guard);
}

const transcribePath = path.join(ROOT, "apps/api/app/api/transcribe/route.ts");
if (!fs.existsSync(transcribePath)) {
  failures.push("stale validator target: apps/api/app/api/transcribe/route.ts missing on disk");
} else {
  const transcribe = fs.readFileSync(transcribePath, "utf8");
  if (!transcribe.includes("MAX_AUDIO_BYTES")) {
    failures.push("transcribe must enforce audio size limit");
  }
}

const recorderPath = path.join(ROOT, manifest.captureAttestClientFile);
if (!fs.existsSync(recorderPath)) {
  failures.push(
    `stale validator target: ${manifest.captureAttestClientFile} is listed in active-api-routes-manifest but missing on disk`,
  );
} else {
  const recorder = fs.readFileSync(recorderPath, "utf8");
  if (!recorder.includes("ensureCaptureAttested")) {
    failures.push("Recorder must attest before OpenAI routes");
  }
}

const apiErrorHelper = path.join(ROOT, "packages/shared/lib/server/api-error-response.ts");
if (!fs.existsSync(apiErrorHelper)) {
  failures.push("missing packages/shared/lib/server/api-error-response.ts");
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

const apiErrorTests = spawnSync("npm", ["run", "validate:api-error-response"], {
  cwd: ROOT,
  stdio: "inherit",
  env: process.env,
});
if (apiErrorTests.status !== 0) {
  process.exit(apiErrorTests.status ?? 1);
}

console.log("validate-api-guard ok (static + grade-a-blockers-tests + api-error-response)");
