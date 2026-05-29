#!/usr/bin/env node
/**
 * Staging/live proof — honest: blocked locally unless VOICEMEMORY_STAGING_PROOF=1.
 * Exit 0 = pass on staging host
 * Exit 1 = staging proof failed
 * Exit 2 = STAGING_BLOCKED (local / missing sign-off when required)
 */
import { writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { formatProofChecks } from "../lib/proof/proof-result.ts";
import { validateStagingProofStatusFile } from "../lib/proof/signoff-validation.ts";
import { validateStagingProof } from "../lib/server/staging-proof-check.ts";

const requireProof =
  process.env.VOICEMEMORY_STAGING_PROOF === "1" || process.argv.includes("--require");

const report = await validateStagingProof({ require: requireProof });

for (const check of report.checks) {
  const tag = check.status.toUpperCase();
  console.log(`${tag.padEnd(8)} ${check.name}: ${check.detail}`);
}

const out = resolve(
  process.env.HOME ?? "/Users/chiragpatel",
  "Desktop/spp20/staging_proof_results.md",
);

const statusFileChecks = requireProof ? validateStagingProofStatusFile() : [];
if (statusFileChecks.length) {
  console.log("\n— staging_proof_status.json —");
  formatProofChecks(statusFileChecks);
}

const statusBlocked = statusFileChecks.some((c) => c.status === "blocked");
const overallBlocked = report.blocked || statusBlocked;

const lines = [
  "# Staging proof results",
  "",
  `**At:** ${new Date().toISOString()}`,
  `**Mode:** ${report.blocked ? "STAGING_BLOCKED (set VOICEMEMORY_STAGING_PROOF=1 on staging)" : requireProof ? "STAGING REQUIRED" : "not required"}`,
  "",
  "| Check | Status | Detail |",
  "|-------|--------|--------|",
  ...report.checks.map((c) => `| ${c.name} | ${c.status} | ${c.detail} |`),
  ...(statusFileChecks.length
    ? [
        "",
        "## Status file",
        "",
        ...statusFileChecks.map((c) => `| ${c.name} | ${c.status} | ${c.detail} |`),
      ]
    : []),
  "",
  `**Overall:** ${overallBlocked ? "STAGING_BLOCKED" : report.ok && !statusBlocked ? "PASS" : "FAIL"}`,
];

writeFileSync(out, lines.join("\n"));
console.log(`\nWrote ${out}`);

if (report.blocked || !requireProof) {
  console.warn("\nvalidate:staging-proof — STAGING_BLOCKED (honest — not run on this host)\n");
  process.exit(2);
}

if (!report.ok || statusBlocked) {
  console.error("\nvalidate:staging-proof — FAIL (fix staging checks or status files)\n");
  process.exit(1);
}

if (report.wroteStatus) {
  console.log("Wrote fresh staging_proof_status.json");
}
console.log("\nvalidate:staging-proof — PASS\n");
process.exit(0);
