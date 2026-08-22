#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const REQUIRED_EVENTS = [
  "callback_shown",
  "callback_dismissed",
  "not_me_clicked",
  "rerecord_within_10min",
  "quote_backed_shown",
  "generic_phrase_shown",
  "low_confidence_suppressed",
];

const metrics = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/resurfacing/resurfacing-metrics.ts"),
  "utf8",
);
for (const ev of REQUIRED_EVENTS) {
  if (!metrics.includes(ev)) failures.push(`resurfacing-metrics missing ${ev}`);
}

const store = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/server/resurfacing-metrics-store.ts"),
  "utf8",
);
if (!store.includes("phrase_key_hash")) {
  failures.push("server metrics must hash phrase keys");
}
if (store.includes("transcript")) failures.push("server metrics must not reference transcript");

const route = fs.readFileSync(
  path.join(ROOT, "apps/api/app/api/metrics/resurfacing/route.ts"),
  "utf8",
);
if (!route.includes("403")) failures.push("metrics GET must be founder-only");

const db = fs.readFileSync(path.join(ROOT, "packages/shared/lib/server/db.ts"), "utf8");
if (!db.includes("resurfacing_events")) failures.push("resurfacing_events table missing");
if (!db.includes("resurfacing_feedback")) failures.push("resurfacing_feedback table missing");

if (failures.length) {
  console.error("validate-field-metrics failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-field-metrics ok");
