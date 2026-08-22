#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const PRESSURE_FILE = path.join(ROOT, "packages/shared/lib/behavior/product-pressure.ts");
const failures = [];

if (!fs.existsSync(PRESSURE_FILE)) {
  failures.push("missing lib/behavior/product-pressure.ts");
} else {
  const text = fs.readFileSync(PRESSURE_FILE, "utf8");
  if (!text.includes("computeProductPressureWarnings")) {
    failures.push("product-pressure must export computeProductPressureWarnings");
  }
  if (!text.includes("continuity surfaces")) {
    failures.push("product-pressure must warn about continuity surface stacking");
  }
  if (!text.includes("introspection operating system")) {
    failures.push("product-pressure must detect feature-density risk");
  }
}

const insight = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/behavior/insight-summary.ts"),
  "utf8",
);
if (!insight.includes("productPressure")) {
  failures.push("insight-summary must consume product pressure warnings");
}

if (failures.length > 0) {
  console.error("Product pressure validation failed:\n");
  for (const f of failures) console.error(`  ${f}`);
  process.exit(1);
}

console.log("Product pressure validation passed.");
