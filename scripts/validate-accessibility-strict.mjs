#!/usr/bin/env node
/**
 * Static gate for strict WCAG production accessibility — complements test:a11y.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

function read(rel) {
  return fs.readFileSync(path.join(ROOT, rel), "utf8");
}

const a11ySpec = read("e2e/ui-a11y.spec.ts");
if (a11ySpec.includes("toBeLessThanOrEqual(4)")) {
  failures.push("e2e/ui-a11y.spec.ts still allows up to 4 contrast violations");
}
if (a11ySpec.includes("ALLOWLIST_SERIOUS") && !a11ySpec.includes("new Set<string>()")) {
  const m = a11ySpec.match(/ALLOWLIST_SERIOUS\s*=\s*new Set\(\[([^\]]*)\]/);
  if (m && m[1].trim().length > 0) {
    failures.push("e2e/ui-a11y.spec.ts has non-empty ALLOWLIST_SERIOUS");
  }
}
if (!a11ySpec.includes("PRIMARY_ROUTES")) {
  failures.push("e2e/ui-a11y.spec.ts must define PRIMARY_ROUTES");
}
for (const route of [
  "/settings",
  "/monthly",
  "/welcome",
  "/privacy",
  "/reminders",
]) {
  if (!a11ySpec.includes(`"${route}"`)) {
    failures.push(`e2e/ui-a11y.spec.ts missing primary route ${route}`);
  }
}

const globals = read("app/globals.css");
if (!globals.includes(".text-muted")) {
  failures.push("app/globals.css missing .text-muted token");
}
if (!globals.includes("prefers-reduced-motion")) {
  failures.push("app/globals.css missing prefers-reduced-motion block");
}

const button = read("components/ui/button.tsx");
if (button.includes("bg-violet-500 text-white")) {
  failures.push("components/ui/button.tsx still uses bg-violet-500 text-white (sub-AA pair)");
}

if (!fs.existsSync(path.join(ROOT, "components/layout/PrimaryMain.tsx"))) {
  failures.push("missing components/layout/PrimaryMain.tsx");
}

const siteHeader = read("components/SiteHeader.tsx");
if (!siteHeader.includes("Skip to main content")) {
  failures.push("SiteHeader missing skip link");
}

const fullA11y = read("e2e/ui-a11y-full.spec.ts");
if (fullA11y.includes("ALLOWLIST_SERIOUS") && /ALLOWLIST_SERIOUS\s*=\s*new Set\(\[[^\]]+\]/.test(fullA11y)) {
  failures.push("e2e/ui-a11y-full.spec.ts has non-empty ALLOWLIST_SERIOUS");
}

const pkg = read("package.json");
if (!pkg.includes('"validate:accessibility-strict"')) {
  failures.push('package.json missing script "validate:accessibility-strict"');
}
if (!pkg.includes('"test:a11y"')) {
  failures.push("package.json missing test:a11y");
}
if (!pkg.includes('"test:a11y:full"')) {
  failures.push("package.json missing test:a11y:full");
}
if (!pkg.includes('"validate:accessibility-full"')) {
  failures.push("package.json missing validate:accessibility-full");
}

const primaryPages = [
  "app/journal/page.tsx",
  "app/memory/page.tsx",
  "app/export/page.tsx",
  "app/settings/page.tsx",
  "app/reminders/page.tsx",
];
for (const rel of primaryPages) {
  const text = read(rel);
  if (!text.includes("PrimaryMain") && !text.includes('<main id="main-content"')) {
    failures.push(`${rel} missing PrimaryMain or main#main-content`);
  }
}

if (failures.length) {
  console.error("validate:accessibility-strict FAILED:\n");
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}

console.log("validate:accessibility-strict passed");
