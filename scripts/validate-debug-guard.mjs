#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const middleware = fs.readFileSync(path.join(ROOT, "middleware.ts"), "utf8");
if (!middleware.includes("isDeprecatedDebugPath")) {
  failures.push("middleware must retire /debug paths");
}
if (!middleware.includes("/internal")) {
  failures.push("middleware must protect /internal");
}
if (!middleware.includes("/demo")) {
  failures.push("middleware must protect /demo");
}
if (!middleware.includes("denyNotFound")) {
  failures.push("middleware must 404 blocked routes");
}

const gate = fs.readFileSync(path.join(ROOT, "lib/middleware/internal-gate.ts"), "utf8");
if (!gate.includes("tier1_production_denied")) {
  failures.push("internal-gate must deny tier1 routes in production");
}

const atmosphere = fs.readFileSync(path.join(ROOT, "app/api/atmosphere/route.ts"), "utf8");
if (!atmosphere.includes("guardOpenAiRoute")) {
  failures.push("atmosphere must use guardOpenAiRoute");
}

if (fs.existsSync(path.join(ROOT, "app/debug"))) {
  failures.push("app/debug must be removed");
}

if (!fs.existsSync(path.join(ROOT, "app/internal/layout.tsx"))) {
  failures.push("app/internal/layout.tsx required");
}

for (const rel of [
  "app/api/billing/checkout/route.ts",
  "app/api/billing/webhook/route.ts",
  "app/api/journal/route.ts",
  "lib/billing/stripe-config.ts",
  "app/api/internal/auth-env/route.ts",
]) {
  if (!fs.existsSync(path.join(ROOT, rel))) failures.push(`missing ${rel}`);
}

if (failures.length) {
  console.error("validate-debug-guard failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-debug-guard ok");
