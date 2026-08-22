#!/usr/bin/env node
/**
 * Static structural WCAG gate for the full public launch surface (Tiers A–C).
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  DYNAMIC_PAGE_FILES,
  LAUNCH_SURFACE,
  TIER_B_PAGE_FILES,
  TIER_C_PAGE_FILES,
} from "./accessibility-route-tiers-data.mjs";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

function read(rel) {
  return fs.readFileSync(path.join(ROOT, rel), "utf8");
}

const fullSpec = read("e2e/ui-a11y-full.spec.ts");
if (!fullSpec.includes("LAUNCH_SURFACE_ROUTES")) {
  failures.push("e2e/ui-a11y-full.spec.ts must scan LAUNCH_SURFACE_ROUTES");
}
if (fullSpec.includes("toBeLessThanOrEqual(4)")) {
  failures.push("e2e/ui-a11y-full.spec.ts still allows contrast budget");
}

for (const rel of [...TIER_B_PAGE_FILES, ...TIER_C_PAGE_FILES, ...DYNAMIC_PAGE_FILES]) {
  const text = read(rel);
  if (
    !text.includes("PrimaryMain") &&
    !text.includes("TrustPageShell") &&
    !text.includes('<main id="main-content"')
  ) {
    failures.push(`${rel} missing PrimaryMain, TrustPageShell, or main#main-content`);
  }
}

const siteHeader = read("apps/web/components/SiteHeader.tsx");
if (!siteHeader.includes('href="#main-content"')) {
  failures.push("SiteHeader skip link must target #main-content");
}

const routesHelper = read("e2e/helpers/accessibility-routes.ts");
for (const route of LAUNCH_SURFACE) {
  if (!routesHelper.includes(`"${route}"`)) {
    failures.push(`e2e/helpers/accessibility-routes.ts missing ${route}`);
  }
}

const dynamicSpec = read("e2e/ui-a11y-dynamic.spec.ts");
if (!dynamicSpec.includes("installA11yDynamicSeed")) {
  failures.push("e2e/ui-a11y-dynamic.spec.ts must use installA11yDynamicSeed");
}
if (!fs.existsSync(path.join(ROOT, "e2e/fixtures/a11y-dynamic-seed.json"))) {
  failures.push("missing e2e/fixtures/a11y-dynamic-seed.json — run generate-a11y-dynamic-seed.mjs");
}

const pkg = read("package.json");
if (!pkg.includes('"test:a11y:dynamic"')) {
  failures.push("package.json missing test:a11y:dynamic");
}
if (!pkg.includes('"test:a11y:dynamic-permutations"')) {
  failures.push("package.json missing test:a11y:dynamic-permutations");
}
if (!pkg.includes('"validate:screen-reader-structure"')) {
  failures.push("package.json missing validate:screen-reader-structure");
}
if (!fs.existsSync(path.join(ROOT, "e2e/ui-a11y-dynamic-permutations.spec.ts"))) {
  failures.push("missing e2e/ui-a11y-dynamic-permutations.spec.ts");
}

if (failures.length) {
  console.error("validate:wcag-launch-surface FAILED:\n");
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}

console.log(
  `validate:wcag-launch-surface passed (${LAUNCH_SURFACE.length} static + dynamic fixture routes)`,
);
