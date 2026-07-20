#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const health = fs.readFileSync(path.join(ROOT, "app/api/health/route.ts"), "utf8");
const healthz = fs.readFileSync(path.join(ROOT, "app/api/healthz/route.ts"), "utf8");
if (!health.includes("migrationsOk")) failures.push("health must report migrationsOk");
if (!health.includes("rateLimiterMode")) failures.push("health must report rateLimiterMode");
if (!healthz.includes('status: "ok"')) failures.push("healthz must return shallow ok status");
if (/verifyMigrations|hasDatabaseUrl|DATABASE_URL/.test(healthz)) {
  failures.push("healthz must not probe database internals");
}
if (/transcript|OPENAI_API_KEY/.test(health) && health.includes("process.env.OPENAI_API_KEY")) {
  // env check ok; must not return secrets
}
if (health.includes("STRIPE_SECRET")) failures.push("health must not expose stripe secrets");

const log = fs.readFileSync(path.join(ROOT, "lib/server/structured-log.ts"), "utf8");
if (!log.includes("transcript")) failures.push("structured-log must ban transcript fields");

const shutdown = fs.readFileSync(
  path.join(ROOT, "lib/server/graceful-shutdown.ts"),
  "utf8",
);
if (!shutdown.includes("SIGTERM")) {
  failures.push("graceful-shutdown must handle SIGTERM");
}
if (!shutdown.includes("broadcastCoordinatorDisconnect")) {
  failures.push("graceful-shutdown must broadcast coordinator_disconnect");
}

const registry = fs.readFileSync(
  path.join(ROOT, "lib/live-audio/live-audio-connection-registry.ts"),
  "utf8",
);
if (!registry.includes("coordinator_disconnect")) {
  failures.push("live-audio connection registry must define coordinator_disconnect");
}

if (failures.length) {
  console.error("validate-health failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-health ok");
