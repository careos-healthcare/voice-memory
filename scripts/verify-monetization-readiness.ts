import path from "node:path";
import { fileURLToPath } from "node:url";

import { archiveMeMonetizationPolicy } from "../lib/monetization/generated/archiveMeMonetizationPolicy";
import { validateProductionUsageAllowances } from "../lib/server/usage-allowance-config";
import { verifyMonetizationReadiness } from "./monetization-readiness-verifier.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
void main();

async function main() {
  const errors = await verifyMonetizationReadiness({
    root,
    policy: archiveMeMonetizationPolicy,
  });
  errors.push(...validateProductionUsageAllowances());

  if (errors.length > 0) {
    console.error("Monetization readiness verification failed:");
    for (const error of errors) console.error(`- ${error}`);
    process.exitCode = 1;
  } else {
    console.log(
      `PASS: policy, guards, deployment usage configuration, and documentation agree at ${archiveMeMonetizationPolicy.policyVersion}.`,
    );
    console.log(
      "NOT AUTOMATICALLY TESTABLE: App Store/Play pricing, offering availability, renewals, refunds, and revocations.",
    );
    console.log(
      "REQUIRES REAL STORE SANDBOX TEST: monthly purchase, annual purchase, restore, expiry, and revocation.",
    );
  }
}
