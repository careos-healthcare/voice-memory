#!/usr/bin/env node
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

function readGuardedRoute(relPath, guardNames) {
  const absolute = path.join(ROOT, relPath);
  if (!fs.existsSync(absolute)) {
    failures.push(
      `stale validator target: ${relPath} is listed in active-api-routes-manifest but missing on disk`,
    );
    return null;
  }
  const text = fs.readFileSync(absolute, "utf8");
  if (!guardNames.some((guard) => text.includes(guard))) {
    failures.push(`${relPath} missing API guard (${guardNames.join(" or ")})`);
  }
  return text;
}

for (const route of manifest.guardedOpenAi) {
  readGuardedRoute(route.routeFile, [route.guard]);
}

for (const route of manifest.guardedAttest) {
  readGuardedRoute(route.routeFile, [route.guard]);
}

for (const rel of manifest.activeApiRouteFiles) {
  const absolute = path.join(ROOT, rel);
  if (!fs.existsSync(absolute)) {
    failures.push(
      `stale validator target: ${rel} is listed in active-api-routes-manifest but missing on disk`,
    );
    continue;
  }
  const routeText = fs.readFileSync(absolute, "utf8");
  if (/NextResponse\.json\(\s*\{\s*error:\s*["']/.test(routeText)) {
    failures.push(`${rel} uses legacy flat error response shape`);
  }
  if (/\{ error: error\.message/.test(routeText)) {
    failures.push(`${rel} exposes raw error.message to clients`);
  }
  if (/\{ error: message, code:/.test(routeText)) {
    failures.push(`${rel} exposes raw exception message to clients`);
  }
}

const apiRouteDir = path.join(ROOT, "apps/api/app/api");
function walkApiRoutes(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const absolute = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walkApiRoutes(absolute);
      continue;
    }
    if (entry.name !== "route.ts") continue;
    const rel = path.relative(ROOT, absolute).split(path.sep).join("/");
    if (manifest.activeApiRouteFiles.includes(rel)) continue;
    const routeText = fs.readFileSync(absolute, "utf8");
    if (/NextResponse\.json\(\s*\{\s*error:\s*["']/.test(routeText)) {
      failures.push(`${rel} uses legacy flat error response shape`);
    }
    if (/\{ error: error\.message/.test(routeText)) {
      failures.push(`${rel} exposes raw error.message to clients`);
    }
    if (/\{ error: message, code:/.test(routeText)) {
      failures.push(`${rel} exposes raw exception message to clients`);
    }
  }
}
if (fs.existsSync(apiRouteDir)) {
  walkApiRoutes(apiRouteDir);
}

const accountDel = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/server/account-deletion.ts"),
  "utf8",
);
const deletionChecks = [
  ["sync_blobs", /sync_blobs/],
  ["sessions", /sessions/],
  ["journal_entries", /journal_entries|deleteAllServerJournalEntries/],
  ["billing_entitlements", /billing_entitlements|deleteServerBilling/],
  ["resurfacing_events", /resurfacing_events/],
  ["api_usage", /api_usage/],
  ["openai_daily_spend", /openai_daily_spend/],
];
for (const [label, re] of deletionChecks) {
  if (!re.test(accountDel)) failures.push(`account-deletion missing ${label}`);
}

const accountDeleteRoute = path.join(ROOT, "apps/api/app/api/account/delete/route.ts");
if (!fs.existsSync(accountDeleteRoute)) {
  failures.push("missing apps/api/app/api/account/delete/route.ts");
} else {
  const routeText = fs.readFileSync(accountDeleteRoute, "utf8");
  if (routeText.includes("sessionRevokeError")) {
    failures.push("account/delete must not expose sessionRevokeError");
  }
  if (!routeText.includes("apiErrorResponse") && !routeText.includes("SESSION_REVOKE_FAILED")) {
    failures.push("account/delete must use sanitized API error contract");
  }
}

if (!fs.existsSync(path.join(ROOT, "packages/shared/lib/server/webhook-idempotency.ts"))) {
  failures.push("missing webhook idempotency");
}

const capture = fs.readFileSync(path.join(ROOT, "packages/shared/lib/capture/capture-token.ts"), "utf8");
if (!capture.includes("ipHash")) failures.push("capture token missing IP binding");

const middleware = fs.readFileSync(path.join(ROOT, "apps/web/middleware.ts"), "utf8");
if (!middleware.includes("isDeprecatedDebugPath")) failures.push("middleware must retire /debug");
if (!middleware.includes("/internal")) failures.push("middleware must guard /internal");

const apiErrorHelper = path.join(ROOT, "packages/shared/lib/server/api-error-response.ts");
if (!fs.existsSync(apiErrorHelper)) {
  failures.push("missing api-error-response helper");
} else {
  const helperText = fs.readFileSync(apiErrorHelper, "utf8");
  if (!helperText.includes("apiMethodNotAllowed")) {
    failures.push("api-error-response must export apiMethodNotAllowed");
  }
}

const notes = manifest.securityResponseHeadersNotes;
if (!notes?.webApp || !notes?.apiApp) {
  failures.push("active-api-routes-manifest missing security header notes");
}

if (failures.length) {
  console.error("validate-security-aplus failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-security-aplus ok");
