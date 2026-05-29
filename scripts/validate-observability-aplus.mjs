#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const health = fs.readFileSync(path.join(ROOT, "app/api/health/route.ts"), "utf8");
for (const field of [
  "rateLimiterMode",
  "migrationsOk",
  "stripeConfigured",
  "emailMode",
]) {
  if (!health.includes(field)) failures.push(`health missing ${field}`);
}
if (health.includes("STRIPE_SECRET") || health.includes("OPENAI_API_KEY")) {
  failures.push("health must not expose secrets");
}

const log = fs.readFileSync(path.join(ROOT, "lib/server/structured-log.ts"), "utf8");
if (!log.includes("logServerEvent")) failures.push("structured log helper missing");

if (failures.length) {
  console.error("validate-observability-aplus failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-observability-aplus ok");
