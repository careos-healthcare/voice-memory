#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const middleware = fs.readFileSync(path.join(ROOT, "apps/web/middleware.ts"), "utf8");
if (!middleware.includes("/internal")) failures.push("middleware must guard /internal");
if (!middleware.includes("/demo")) failures.push("middleware must guard /demo");
if (!middleware.includes("404")) failures.push("middleware must 404 blocked routes");

const founder = fs.readFileSync(path.join(ROOT, "packages/shared/lib/server/founder-access.ts"), "utf8");
if (!founder.includes("isFounderEmail")) failures.push("founder-access missing isFounderEmail");

const metrics = fs.readFileSync(
  path.join(ROOT, "apps/api/app/api/metrics/resurfacing/route.ts"),
  "utf8",
);
if (!metrics.includes("403")) failures.push("metrics GET must forbid non-founders");

const internalDir = path.join(ROOT, "apps/web/app/internal");
if (!fs.existsSync(internalDir)) failures.push("apps/web/app/internal missing");
else {
  const pages = fs.readdirSync(internalDir, { withFileTypes: true }).filter((d) => d.isDirectory());
  if (pages.length < 20) failures.push("expected consolidated internal routes");
}

if (fs.existsSync(path.join(ROOT, "apps/web/app/debug"))) {
  failures.push("apps/web/app/debug must not exist after migration");
}

const prodEnv = fs.readFileSync(path.join(ROOT, "packages/shared/lib/server/production-env.ts"), "utf8");
if (!prodEnv.includes("isDebugTokenStrong")) {
  failures.push("production-env must validate DEBUG_ACCESS_TOKEN strength");
}
if (!prodEnv.includes("/internal")) {
  failures.push("production-env should reference /internal not legacy /debug only");
}

const pageGuard = fs.readFileSync(path.join(ROOT, "packages/shared/lib/server/internal-page-guard.ts"), "utf8");
if (!pageGuard.includes("assertInternalPageAccess")) {
  failures.push("internal-page-guard missing");
}

const founderMode = fs.readFileSync(path.join(ROOT, "packages/shared/lib/server/founder-mode.ts"), "utf8");
if (!founderMode.includes("FOUNDER_MODE")) {
  failures.push("founder-mode.ts must document FOUNDER_MODE");
}
const internalAccess = fs.readFileSync(path.join(ROOT, "packages/shared/lib/server/internal-access.ts"), "utf8");
if (!internalAccess.includes("isFounderModeEnabled")) {
  failures.push("internal-access must require FOUNDER_MODE");
}

if (failures.length) {
  console.error("validate-internal-routes failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-internal-routes ok");
