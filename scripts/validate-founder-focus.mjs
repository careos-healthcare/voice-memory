#!/usr/bin/env node
/**
 * Founder Complexity Reduction v2
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];
const fail = (msg) => failures.push(msg);

function read(rel) {
  return fs.readFileSync(path.join(ROOT, rel), "utf8");
}

function mustExist(rel) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

for (const rel of [
  "packages/shared/types/founder-focus.ts",
  "packages/shared/lib/internal/founder-priority.ts",
  "packages/shared/lib/internal/founder-focus-copy.ts",
  "packages/shared/lib/internal/north-star-report.ts",
  "packages/shared/lib/internal/founder-archive-dashboard.ts",
  "packages/shared/lib/product/feature-filter.ts",
  "apps/web/components/internal/FounderInternalNav.tsx",
  "apps/web/components/internal/FounderModePreamble.tsx",
  "apps/web/components/internal/NorthStarDashboard.tsx",
  "apps/web/components/internal/FounderArchiveDashboard.tsx",
  "apps/web/app/internal/north-star/page.tsx",
  "apps/web/app/internal/archive/page.tsx",
]) {
  mustExist(rel);
}

const copy = read("packages/shared/lib/internal/founder-focus-copy.ts");
for (const token of [
  "The biggest risk is not missing features",
  "First archive belief",
  "Archive curiosity",
  "Return behavior",
  "Paid conversion",
  "Activation Rate",
  "Archive Return Rate",
  "Archive Curiosity Rate",
  "Subscription Conversion",
  "Archive Attachment",
]) {
  if (!copy.includes(token)) fail(`founder-focus-copy missing ${token}`);
}

const northStarReport = read("packages/shared/lib/internal/north-star-report.ts");
if (!northStarReport.includes("NORTH_STAR_METRIC_COUNT = 5")) {
  fail("north-star-report must cap at 5 metrics");
}

const northStarPage = read("apps/web/app/internal/north-star/page.tsx");
const northStarDash = read("apps/web/components/internal/NorthStarDashboard.tsx");
if (!northStarPage.includes("NorthStarDashboard")) {
  fail("north-star page must render NorthStarDashboard only");
}
if (northStarDash.includes("sm:grid-cols-3")) {
  fail("north star must not expose a sixth metric column layout");
}

const archiveDash = read("apps/web/components/internal/FounderArchiveDashboard.tsx");
const archiveDashLib = read("packages/shared/lib/internal/founder-archive-dashboard.ts");
if (!archiveDash.includes("FOUNDER_DASHBOARD_TAB_COUNT")) {
  fail("FounderArchiveDashboard must reference FOUNDER_DASHBOARD_TAB_COUNT");
}
if (!archiveDashLib.includes("FOUNDER_DASHBOARD_TAB_COUNT = 3")) {
  fail("founder-archive-dashboard must define exactly 3 tabs");
}
for (const tab of ["activation", "return", "conversion"]) {
  if (!archiveDashLib.includes(tab)) fail(`founder-archive-dashboard missing tab ${tab}`);
}

const priority = read("packages/shared/lib/internal/founder-priority.ts");
for (const token of ["CORE", "ARCHIVED", "changesProductDecision", "getFounderPanelPriorityRegistry"]) {
  if (!priority.includes(token)) fail(`founder-priority missing ${token}`);
}

const featureFilter = read("packages/shared/lib/product/feature-filter.ts");
if (!featureFilter.includes("LOW PRIORITY")) {
  fail("feature-filter must flag LOW PRIORITY");
}
for (const axis of ["improvesActivation", "improvesReturn", "improvesConversion"]) {
  if (!featureFilter.includes(axis)) fail(`feature-filter missing ${axis}`);
}

const layout = read("apps/web/app/internal/layout.tsx");
if (!layout.includes("FounderInternalNav")) {
  fail("internal layout must render FounderInternalNav");
}

const nav = read("apps/web/components/internal/FounderInternalNav.tsx");
const navCopy = read("packages/shared/lib/internal/founder-focus-copy.ts");
if (!nav.includes("FOUNDER_INTERNAL_NAV")) {
  fail("FounderInternalNav must use FOUNDER_INTERNAL_NAV");
}
if (
  !navCopy.includes('href: "/internal"') ||
  !navCopy.includes('href: "/internal/launch"')
) {
  fail("FOUNDER_INTERNAL_NAV must define command center and launch only");
}

const hubFiles = [
  "apps/web/app/internal/founder-test/FounderTestShell.tsx",
  "apps/web/app/internal/retention-discovery/page.tsx",
];
const allowedHubTargets = ["/internal", "/internal/launch", "/internal/activation", "/internal/return", "/internal/conversion", "/internal/distribution", "/internal/mobile-readiness"];
for (const rel of hubFiles) {
  const src = read(rel);
  const hrefs = [...src.matchAll(/href="(\/internal\/[^"]+)"/g)].map((m) => m[1]);
  for (const href of hrefs) {
    if (!allowedHubTargets.includes(href)) {
      fail(`${rel} must not link to secondary internal route ${href}`);
    }
  }
}

try {
  const { buildNorthStarDashboard, NORTH_STAR_METRIC_COUNT } = await import(
    path.join(ROOT, "packages/shared/lib/internal/north-star-report.ts")
  );
  const view = buildNorthStarDashboard();
  if (view.metrics.length !== NORTH_STAR_METRIC_COUNT) {
    fail(`north star must expose ${NORTH_STAR_METRIC_COUNT} metrics, got ${view.metrics.length}`);
  }
  const { getFounderPanelPriorityRegistry, NORTH_STAR_METRIC_IDS, FOUNDER_DASHBOARD_TAB_IDS } =
    await import(path.join(ROOT, "packages/shared/lib/internal/founder-priority.ts"));
  if (NORTH_STAR_METRIC_IDS.length !== 5) fail("NORTH_STAR_METRIC_IDS must be 5");
  if (FOUNDER_DASHBOARD_TAB_IDS.length !== 3) fail("FOUNDER_DASHBOARD_TAB_IDS must be 3");
  const registry = getFounderPanelPriorityRegistry();
  const core = registry.filter((r) => r.tier === "CORE");
  if (core.length !== 8) {
    fail(`expected 5 north-star + 3 tab CORE entries, got ${core.length}`);
  }
  const archivedNoDecision = registry.filter(
    (r) => r.tier === "ARCHIVED" && r.changesProductDecision !== "NO",
  );
  if (archivedNoDecision.length > 0) {
    fail("ARCHIVED panels must have changesProductDecision NO");
  }
} catch (e) {
  fail(`import check failed: ${e.message}`);
}

function listInternalRoutes() {
  const internalRoot = path.join(ROOT, "apps/web/app/internal");
  const routes = [];
  if (fs.existsSync(path.join(internalRoot, "page.tsx"))) {
    routes.push("/internal");
  }
  function walk(dir, prefix) {
    for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
      if (!ent.isDirectory()) continue;
      const route = `${prefix}/${ent.name}`;
      if (fs.existsSync(path.join(dir, ent.name, "page.tsx"))) routes.push(route);
      walk(path.join(dir, ent.name), route);
    }
  }
  walk(internalRoot, "/internal");
  return routes;
}

const routes = listInternalRoutes();
if (!routes.includes("/internal")) fail("missing /internal command center route");
if (!routes.includes("/internal/activation")) fail("missing /internal/activation route");
if (!routes.includes("/internal/return")) fail("missing /internal/return route");
if (!routes.includes("/internal/conversion")) fail("missing /internal/conversion route");
if (!routes.includes("/internal/launch")) fail("missing /internal/launch route");

const pkg = JSON.parse(read("package.json"));
if (!pkg.scripts?.["validate:founder-focus"]) {
  fail("package.json missing validate:founder-focus");
}

if (failures.length) {
  console.error("validate-founder-focus failed:\n");
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log("validate-founder-focus ok");
