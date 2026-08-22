#!/usr/bin/env node
/**
 * Internal Complexity Reduction v1
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

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
  "packages/shared/lib/internal/internal-surface-registry.ts",
  "packages/shared/lib/internal/internal-complexity-report.ts",
  "packages/shared/lib/server/founder-mode.ts",
  "scripts/validate-internal-complexity.mjs",
  "scripts/generate-internal-complexity-report.mjs",
]) {
  mustExist(rel);
}

const registry = read("packages/shared/lib/internal/internal-surface-registry.ts");
for (const kind of ["dashboard", "validator", "founder_panel", "experiment_panel"]) {
  if (!registry.includes(`"${kind}"`)) fail(`registry missing kind ${kind}`);
}

const founderMode = read("packages/shared/lib/server/founder-mode.ts");
if (!founderMode.includes('FOUNDER_MODE') || !founderMode.includes("isFounderModeEnabled")) {
  fail("founder-mode.ts must define FOUNDER_MODE gate");
}

for (const file of [
  "packages/shared/lib/server/internal-access.ts",
  "packages/shared/lib/middleware/internal-gate.ts",
]) {
  const src = read(file);
  if (!src.includes("isFounderModeEnabled")) {
    fail(`${file} must gate on isFounderModeEnabled`);
  }
}

spawnSync("node", ["--import", "tsx", "scripts/generate-internal-complexity-report.mjs"], {
  cwd: ROOT,
  stdio: "inherit",
});

if (!fs.existsSync(path.join(ROOT, "docs/INTERNAL_COMPLEXITY_REPORT.md"))) {
  fail("docs/INTERNAL_COMPLEXITY_REPORT.md not generated");
}

const scoreCheck = spawnSync(
  "node",
  [
    "--import",
    "tsx",
    "-e",
    `import {
  countActiveInternalPanels,
  INTERNAL_COMPLEXITY_ACTIVE_TARGET,
} from './lib/internal/internal-surface-registry.ts';
import { buildInternalComplexityReport } from './lib/internal/internal-complexity-report.ts';
const active = countActiveInternalPanels();
const report = buildInternalComplexityReport();
console.log('Internal Complexity Score:', report.internalComplexityScore);
if (active >= INTERNAL_COMPLEXITY_ACTIVE_TARGET) {
  console.error('active panels', active, 'must be <', INTERNAL_COMPLEXITY_ACTIVE_TARGET);
  process.exit(1);
}
if (report.internalComplexityScore !== active) {
  console.error('score must equal active KEEP count');
  process.exit(1);
}`,
  ],
  { cwd: ROOT, encoding: "utf8" },
);
if (scoreCheck.status !== 0) {
  fail(`active panel target failed: ${scoreCheck.stderr || scoreCheck.stdout}`);
}

const reportMd = read("docs/INTERNAL_COMPLEXITY_REPORT.md");
for (const token of [
  "Public routes",
  "Internal routes",
  "Internal Complexity Score",
  "KEEP",
  "MERGE",
  "DELETE",
]) {
  if (!reportMd.includes(token)) fail(`report missing ${token}`);
}

const layout = read("apps/web/app/internal/layout.tsx");
if (!layout.includes("assertInternalPageAccess")) {
  fail("internal layout must assert access");
}

const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
if (!pkg.scripts["validate:internal-complexity"]) {
  fail("package.json missing validate:internal-complexity");
}
if (!pkg.scripts["generate:internal-complexity-report"]) {
  fail("package.json missing generate:internal-complexity-report");
}

if (failures.length) {
  console.error("validate-internal-complexity failed:\n");
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log(scoreCheck.stdout.trim());
console.log("validate-internal-complexity passed");
