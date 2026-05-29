#!/usr/bin/env node
/**
 * Hard gate: high-risk >=4, medium >=3, no static-only high-risk.
 */
import { writeFileSync } from "node:fs";
import { resolve } from "node:path";
import {
  HIGH_RISK_MIN_SCORE,
  MEDIUM_RISK_MIN_SCORE,
  STATIC_ONLY_LOW_RISK,
  VALIDATOR_INVENTORY,
} from "./validator-confidence-data.mjs";

const failures = [];
const lines = [
  "# Validator confidence inventory",
  "",
  `**Generated:** ${new Date().toISOString().slice(0, 19)}Z`,
  "",
  `**Gate:** high-risk ≥ ${HIGH_RISK_MIN_SCORE}, medium-risk ≥ ${MEDIUM_RISK_MIN_SCORE}`,
  "",
  "| Validator | Risk | Score | Proof | Counterpart |",
  "|-----------|------|-------|-------|-------------|",
];

for (const v of VALIDATOR_INVENTORY) {
  lines.push(
    `| ${v.id} | ${v.risk} | ${v.score} | ${v.proof} | ${v.counterpart ?? "—"} |`,
  );
  if (v.risk === "high" && v.score < HIGH_RISK_MIN_SCORE) {
    failures.push(`${v.id} high-risk score ${v.score} < ${HIGH_RISK_MIN_SCORE}`);
  }
  if (v.risk === "medium" && v.score < MEDIUM_RISK_MIN_SCORE) {
    failures.push(`${v.id} medium-risk score ${v.score} < ${MEDIUM_RISK_MIN_SCORE}`);
  }
  if (v.risk === "high" && v.score === 1 && !STATIC_ONLY_LOW_RISK.includes(v.id)) {
    failures.push(`${v.id} high-risk static-only (score 1)`);
  }
}

lines.push(
  "",
  "## Low-risk static-only (acceptable)",
  "",
  ...STATIC_ONLY_LOW_RISK.map((id) => `- ${id}`),
  "",
  "## Score legend",
  "",
  "1 = static only · 2 = static + unit · 3 = integration · 4 = E2E/runtime · 5 = live proof",
);

const out = resolve(
  process.env.HOME ?? "/Users/chiragpatel",
  "Desktop/spp20/validator_confidence_inventory.md",
);
writeFileSync(out, lines.join("\n"));

if (failures.length) {
  console.error("validate:validator-confidence FAILED:\n");
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}

console.log(`validate:validator-confidence passed (${VALIDATOR_INVENTORY.length} tracked)`);
console.log(`Wrote ${out}`);
