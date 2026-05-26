#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED = [
  "types/entitlement.ts",
  "lib/entitlement/entitlements.ts",
  "lib/entitlement/tiers.ts",
  "lib/entitlement/payment-stack.ts",
  "components/billing/EntitlementGate.tsx",
];

const ENTITLEMENT_READ = path.join(ROOT, "lib/entitlement/entitlements.ts");
const entitlementsSrc = fs.readFileSync(ENTITLEMENT_READ, "utf8");
if (entitlementsSrc.includes("localStorage.setItem(PLAN_KEY") === false) {
  console.error("entitlements.ts must define plan storage for preview tier");
  process.exit(1);
}

const paymentSrc = fs.readFileSync(path.join(ROOT, "lib/entitlement/payment-stack.ts"), "utf8");
if (!paymentSrc.includes("checkoutImplemented: false")) {
  console.error("payment-stack audit must reflect checkout not implemented until wired");
  process.exit(1);
}

for (const rel of REQUIRED) {
  if (!fs.existsSync(path.join(ROOT, rel))) {
    console.error(`Missing required entitlement file: ${rel}`);
    process.exit(1);
  }
}

const subscription = fs.readFileSync(path.join(ROOT, "lib/subscription.ts"), "utf8");
if (!subscription.includes("hasEntitlement")) {
  console.error("subscription.ts must delegate to entitlement layer");
  process.exit(1);
}

console.log("Entitlement restraint validation passed.");
