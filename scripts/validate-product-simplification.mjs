#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];
const fail = (msg) => failures.push(msg);

const required = [
  "lib/product/archive-product-model.ts",
  "types/archive-product-model.ts",
  "lib/product/archive-product-questions.ts",
  "lib/product/surface-audit.ts",
  "lib/internal/product-simplification-report.ts",
  "components/archive/ArchiveCommandCenter.tsx",
  "components/archive/ArchiveDetailsCollapsible.tsx",
  "lib/product/product-simplification-copy.ts",
  "scripts/validate-surface-complexity.mjs",
];

import { spawnSync } from "node:child_process";
spawnSync("node", ["scripts/validate-surface-complexity.mjs"], {
  cwd: ROOT,
  stdio: "inherit",
});
if (!fs.existsSync(path.join(ROOT, "docs/SURFACE_COMPLEXITY_REPORT.md"))) {
  fail("docs/SURFACE_COMPLEXITY_REPORT.md not generated");
}

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const home = fs.readFileSync(
  path.join(ROOT, "components/archive/EvidenceArchiveHome.tsx"),
  "utf8",
);
for (const token of [
  "ArchiveCommandCenter",
  "ArchiveDetailsCollapsible",
  "PAGE_TITLE_ARCHIVE",
]) {
  if (!home.includes(token)) fail(`EvidenceArchiveHome missing ${token}`);
}

const header = fs.readFileSync(path.join(ROOT, "components/SiteHeader.tsx"), "utf8");
const simplicityNav = fs.readFileSync(
  path.join(ROOT, "lib/product/simplicity-mode.ts"),
  "utf8",
);
if (!header.includes("SIMPLICITY_PRIMARY_NAV")) {
  fail("SiteHeader must use SIMPLICITY_PRIMARY_NAV");
}
if (!simplicityNav.includes('href: "/archive-belief"')) fail("simplicity-mode must link Archive");
if (header.includes("TheoryUpdatesNav")) {
  fail("TheoryUpdatesNav must not be in primary SiteHeader");
}

const simplCopy = fs.readFileSync(
  path.join(ROOT, "lib/product/product-simplification-copy.ts"),
  "utf8",
);
const accountNav = fs.readFileSync(
  path.join(ROOT, "components/account/AccountSecondaryNav.tsx"),
  "utf8",
);
for (const label of ["Evidence for belief", "Archive Beliefs", "Reflection Log", "Changes"]) {
  if (!simplCopy.includes(label)) fail(`product-simplification-copy missing ${label}`);
  if (!accountNav.includes("NAV_")) fail("AccountSecondaryNav must use simplification nav constants");
}

const mobileShell = fs.readFileSync(
  path.join(ROOT, "apps/voicememory_mobile/lib/widgets/main_shell.dart"),
  "utf8",
);
for (const label of ["Record", "Archive", "Changes", "Account"]) {
  if (!mobileShell.includes(`label: '${label}'`)) fail(`mobile nav missing ${label}`);
}
if (mobileShell.includes("Journal") || mobileShell.includes("Blind Spots")) {
  fail("mobile primary nav must not include Journal or Blind Spots");
}

const router = fs.readFileSync(
  path.join(ROOT, "apps/voicememory_mobile/lib/router/app_router.dart"),
  "utf8",
);
if (!router.includes("/blind-spots")) fail("mobile must keep /blind-spots route");
if (!router.includes("archive-belief")) fail("mobile must keep archive-belief route");

const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
if (!pkg.scripts["validate:product-simplification"]) {
  fail("package.json missing validate:product-simplification");
}

mustNotDeleteRoutes();

const { buildArchiveProductObject } = await import("../lib/product/archive-product-model.ts");
const { buildSurfaceAuditReport } = await import("../lib/product/surface-audit.ts");
const { buildProductSimplificationReport } = await import(
  "../lib/internal/product-simplification-report.ts"
);

assert.ok(buildArchiveProductObject);
assert.ok(buildSurfaceAuditReport().primary.length >= 1);
assert.ok(buildProductSimplificationReport().oneLiner.includes("archive"));

if (failures.length) {
  console.error(
    "validate:product-simplification failed:\n" + failures.map((f) => `  - ${f}`).join("\n"),
  );
  process.exit(1);
}

console.log("validate:product-simplification OK");

function mustNotDeleteRoutes() {
  const routes = fs
    .readdirSync(path.join(ROOT, "app"), { recursive: true })
    .filter((f) => String(f).endsWith("page.tsx") || String(f).endsWith("route.ts"));
  for (const route of ["/blind-spots", "/theories", "/memory", "/updates", "/discover"]) {
    const needle = route.slice(1);
    if (!routes.some((r) => String(r).includes(needle))) {
      fail(`route removed: ${route}`);
    }
  }
}
