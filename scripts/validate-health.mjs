#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const health = fs.readFileSync(path.join(ROOT, "app/api/health/route.ts"), "utf8");
if (!health.includes("migrationsOk")) failures.push("health must report migrationsOk");
if (!health.includes("rateLimiterMode")) failures.push("health must report rateLimiterMode");
if (/transcript|OPENAI_API_KEY/.test(health) && health.includes("process.env.OPENAI_API_KEY")) {
  // env check ok; must not return secrets
}
if (health.includes("STRIPE_SECRET")) failures.push("health must not expose stripe secrets");

const log = fs.readFileSync(path.join(ROOT, "lib/server/structured-log.ts"), "utf8");
if (!log.includes("transcript")) failures.push("structured-log must ban transcript fields");

if (failures.length) {
  console.error("validate-health failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-health ok");
