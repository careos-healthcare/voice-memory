#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const { ARCHIVE_MOAT_FORBIDDEN, ARCHIVE_MOAT_SCAN_FILES } = await import(
  "../packages/shared/lib/archive/archive-moat-copy.ts"
);

for (const rel of ARCHIVE_MOAT_SCAN_FILES) {
  const full = path.join(ROOT, rel);
  if (!fs.existsSync(full)) {
    failures.push(`missing ${rel}`);
    continue;
  }
  const src = fs.readFileSync(full, "utf8");
  for (const re of ARCHIVE_MOAT_FORBIDDEN) {
    if (re.test(src)) failures.push(`${rel} matches forbidden ${re}`);
  }
}

const proofEngine = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/archive/hard-to-reproduce-proof.ts"),
  "utf8",
);
for (const re of ARCHIVE_MOAT_FORBIDDEN) {
  if (re.test(proofEngine)) failures.push(`hard-to-reproduce-proof matches forbidden ${re}`);
}

if (failures.length) {
  console.error("validate-archive-moat-copy failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-archive-moat-copy ok");
