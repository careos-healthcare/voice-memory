#!/usr/bin/env node
/**
 * Inventory validators — static vs runtime proof classification.
 */
import fs from "node:fs";
import path from "node:path";
import { writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const scriptsDir = path.join(ROOT, "scripts");

const LOW_RISK_STATIC = new Set([
  "validate-quiet-copy",
  "validate-restraint",
  "validate-product-restraint",
  "validate-ux-copy",
  "validate-human-memory-copy",
  "validate-homepage-clarity",
  "validate-synthetic-labels",
  "validate-ui",
  "validate-wcag-launch-surface",
  "validate-accessibility-strict",
]);

const RUNTIME_HINTS = [
  { re: /blockers-tests|run-.*-tests|playwright|hostile-proof|runtime-proof|privacy-logs-tests/i, proof: "integration/E2E", score: 4 },
  { re: /validate:journal|validate:billing|validate:rate-limits|validate:api-guard/i, proof: "integration tests", score: 4 },
  { re: /validate:accessibility-full|test:a11y/i, proof: "axe E2E", score: 4 },
  { re: /tsx.*validate-production|validate-deploy|validate-staging/i, proof: "runtime env/live", score: 5 },
];

function classify(name, content) {
  if (LOW_RISK_STATIC.has(name)) {
    return { proof: "static copy/structure", score: 1, risk: "low", why: "UX copy or inventory only" };
  }
  for (const hint of RUNTIME_HINTS) {
    if (hint.re.test(content) || hint.re.test(name)) {
      return { proof: hint.proof, score: hint.score, risk: "high", why: "Has runtime counterpart" };
    }
  }
  if (/spawnSync|playwright|run-grade-a-blockers/.test(content)) {
    return { proof: "orchestrated runtime", score: 4, risk: "medium", why: "Spawns tests" };
  }
  if (name.includes("restraint") || name.includes("copy")) {
    return { proof: "static string scan", score: 1, risk: "low", why: "Product copy restraint" };
  }
  return { proof: "static file scan", score: 2, risk: "medium", why: "No automated runtime in script" };
}

const files = fs.readdirSync(scriptsDir).filter((f) => f.startsWith("validate-") && f.endsWith(".mjs"));
const rows = [];

for (const file of files.sort()) {
  const name = file.replace(/\.mjs$/, "");
  const content = fs.readFileSync(path.join(scriptsDir, file), "utf8");
  const c = classify(name, content);
  rows.push({ name, npm: `npm run ${name}`, ...c });
}

const md = [
  "# Static validator remaining inventory",
  "",
  `**Generated:** ${new Date().toISOString().slice(0, 19)}Z`,
  "",
  "## High/medium risk — must have runtime proof (score ≥3/4)",
  "",
  "| Script | Risk | Score | Proof | Notes |",
  "|--------|------|-------|-------|-------|",
  ...rows
    .filter((r) => r.risk !== "low")
    .map(
      (r) =>
        `| ${r.name} | ${r.risk} | ${r.score} | ${r.proof} | ${r.why} |`,
    ),
  "",
  "## Low-risk static-only (acceptable)",
  "",
  ...rows
    .filter((r) => r.risk === "low")
    .map((r) => `- \`${r.name}\` — ${r.proof}`),
  "",
  "## Recommended actions",
  "",
  "- Security/billing/auth validators: use `validate:runtime-proof`, `validate:hostile-proof`, or blockers tests — not string search alone.",
  "- Copy/restraint validators: remain static (score 1).",
].join("\n");

const out = resolve(
  process.env.HOME ?? "/Users/chiragpatel",
  "Desktop/spp20/static_validator_remaining_inventory.md",
);
writeFileSync(out, md);
console.log(`Wrote ${out} (${rows.length} validators)`);
