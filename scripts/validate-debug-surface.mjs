#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

function read(rel) {
  return fs.readFileSync(path.join(ROOT, rel), "utf8");
}

const middleware = read("middleware.ts");
if (!middleware.includes("isDeprecatedDebugPath")) {
  failures.push("middleware must block deprecated /debug paths");
}
if (!middleware.includes("/internal")) {
  failures.push("middleware must protect /internal");
}
if (!middleware.includes("status: 404") && !middleware.includes("denyNotFound")) {
  failures.push("middleware must 404 unauthorized access");
}

const gate = read("packages/shared/lib/middleware/internal-gate.ts");
if (/import\s+["']server-only["']/.test(gate)) {
  failures.push("internal-gate must stay edge-safe (no server-only import)");
}

if (!fs.existsSync(path.join(ROOT, "apps/web/app/internal/layout.tsx"))) {
  failures.push("apps/web/app/internal/layout.tsx must gate server-side access");
}
if (!read("apps/web/app/internal/layout.tsx").includes("assertInternalPageAccess")) {
  failures.push("internal layout must call assertInternalPageAccess");
}

if (fs.existsSync(path.join(ROOT, "apps/web/app/debug"))) {
  failures.push("apps/web/app/debug must not exist (migrated to /internal)");
}

const header = read("apps/web/components/SiteHeader.tsx");
if (header.includes('href="/internal') || header.includes('href="/debug')) {
  failures.push("SiteHeader must not link to internal/debug routes");
}

const home = read("apps/web/app/page.tsx");
if (home.match(/href=["']\/(debug|internal)/)) {
  failures.push("home page must not link to internal/debug routes");
}

const record = read("apps/web/app/record/page.tsx");
if (record.match(/href=["']\/(debug|internal)/)) {
  failures.push("record page must not link to internal/debug routes");
}

if (!fs.existsSync(path.join(ROOT, "apps/api/app/api/internal/auth-env/route.ts"))) {
  failures.push("auth-env probe must live under /api/internal/auth-env");
}
if (fs.existsSync(path.join(ROOT, "apps/api/app/api/debug/auth-env/route.ts"))) {
  failures.push("remove legacy /api/debug/auth-env");
}

const internalDir = path.join(ROOT, "apps/web/app/internal");
const slugs = fs
  .readdirSync(internalDir, { withFileTypes: true })
  .filter((d) => d.isDirectory())
  .map((d) => d.name);
if (slugs.length < 20 || slugs.length > 35) {
  failures.push(`expected ~27 internal routes, found ${slugs.length}`);
}

for (const banned of ["retention-readout", "resurfacing-metrics", "callbacks", "moat"]) {
  if (slugs.includes(banned)) {
    failures.push(`dead internal route still present: ${banned}`);
  }
}

const pageGuard = read("packages/shared/lib/server/internal-page-guard.ts");
if (!pageGuard.includes("notFound()")) {
  failures.push("internal-page-guard must notFound()");
}

const pkg = read("package.json");
if (!pkg.includes("validate:debug-surface")) {
  failures.push("package.json must define validate:debug-surface");
}

if (failures.length) {
  console.error("validate:debug-surface FAILED:\n");
  for (const f of failures) console.error(`  ✗ ${f}`);
  process.exit(1);
}

console.log(`validate:debug-surface passed (${slugs.length} internal routes, /debug retired).`);
