#!/usr/bin/env node
/**
 * Real-device proof — requires fresh device_proof_signoff.json when
 * VOICEMEMORY_DEVICE_PROOF_REQUIRED=1. Never fakes hardware flows.
 *
 * Exit 0 = pass or not required
 * Exit 1 = invalid sign-off / stale
 * Exit 2 = DEVICE_BLOCKED (missing sign-off when required)
 */
import { writeFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";
import { formatProofChecks } from "../lib/proof/proof-result.ts";
import { validateDeviceProofSignoff } from "../lib/proof/signoff-validation.ts";
import { DEVICE_SIGNOFF_PATH, SPP20_DIR } from "../lib/proof/signoff-files.ts";

const required = process.env.VOICEMEMORY_DEVICE_PROOF_REQUIRED === "1";
const templatePath = resolve(SPP20_DIR, "device_proof_signoff.template.json");

if (!required) {
  console.log(
    "validate:device-proof — SKIP (set VOICEMEMORY_DEVICE_PROOF_REQUIRED=1 to enforce sign-off)",
  );
  process.exit(0);
}

const checks = validateDeviceProofSignoff();
formatProofChecks(checks);

const blocked = checks.some((c) => c.status === "blocked");
const failed = checks.some((c) => c.status === "fail");

const reportPath = resolve(SPP20_DIR, "device_proof_enforcement_report.md");
const lines = [
  "# Device proof enforcement report",
  "",
  `**At:** ${new Date().toISOString()}`,
  `**Required:** VOICEMEMORY_DEVICE_PROOF_REQUIRED=1`,
  `**Sign-off path:** ${DEVICE_SIGNOFF_PATH}`,
  `**Template:** ${templatePath}`,
  "",
  "| Check | Status | Detail |",
  "|-------|--------|--------|",
  ...checks.map((c) => `| ${c.name} | ${c.status} | ${c.detail} |`),
  "",
  blocked
    ? "**Verdict:** DEVICE_BLOCKED — complete real device checklist; do not fake pass."
    : failed
      ? "**Verdict:** FAIL — fix sign-off JSON."
      : "**Verdict:** PASS",
  "",
];
writeFileSync(reportPath, lines.join("\n"));
console.log(`\nWrote ${reportPath}`);

if (blocked) {
  console.warn("\nvalidate:device-proof — DEVICE_BLOCKED\n");
  process.exit(2);
}
if (failed) {
  console.error("\nvalidate:device-proof — FAIL\n");
  process.exit(1);
}
console.log("\nvalidate:device-proof — PASS\n");
process.exit(0);
