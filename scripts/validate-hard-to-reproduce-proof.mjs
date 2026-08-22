#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];
const fail = (msg) => failures.push(msg);

for (const rel of [
  "packages/shared/lib/archive/hard-to-reproduce-proof.ts",
  "packages/shared/lib/archive/what-archive-can-answer-copy.ts",
  "packages/shared/lib/metrics/hard-to-reproduce-proof-events.ts",
  "apps/web/components/archive/HardToReproduceProof.tsx",
  "apps/web/components/archive/WhatThisArchiveCanAnswer.tsx",
]) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const copy = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/archive/what-archive-can-answer-copy.ts"),
  "utf8",
);
if (!copy.includes("What this archive can answer")) fail("headline missing");
if (!copy.includes("What do I keep doing?")) fail("bullet missing");

const engine = fs.readFileSync(path.join(ROOT, "packages/shared/lib/archive/hard-to-reproduce-proof.ts"), "utf8");
if (!engine.includes("hard to recreate from one prompt")) fail("proof line missing");

const proof = fs.readFileSync(
  path.join(ROOT, "apps/web/components/archive/HardToReproduceProof.tsx"),
  "utf8",
);
if (!proof.includes("trackHardToReproduceProofSeen")) fail("must track seen");

const events = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/metrics/hard-to-reproduce-proof-events.ts"),
  "utf8",
);
for (const name of ["hard_to_reproduce_proof_seen", "hard_to_reproduce_proof_expanded"]) {
  if (!events.includes(name)) fail(`event missing: ${name}`);
}

for (const rel of [
  "apps/web/app/page.tsx",
  "apps/web/app/discover/page.tsx",
  "apps/web/app/memory/page.tsx",
  "apps/web/app/blind-spots/page.tsx",
]) {
  const src = fs.readFileSync(path.join(ROOT, rel), "utf8");
  if (!src.includes("WhatThisArchiveCanAnswer")) fail(`${rel} missing WhatThisArchiveCanAnswer`);
}

if (failures.length) {
  console.error("validate-hard-to-reproduce-proof failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-hard-to-reproduce-proof ok");
