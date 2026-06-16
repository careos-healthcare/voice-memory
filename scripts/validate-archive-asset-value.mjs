#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];
const fail = (msg) => failures.push(msg);

for (const rel of [
  "lib/archive/archive-asset-value.ts",
  "lib/archive/archive-asset-value-copy.ts",
  "lib/metrics/archive-asset-value-events.ts",
  "components/archive/ArchiveAssetCard.tsx",
]) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const copy = fs.readFileSync(
  path.join(ROOT, "lib/archive/archive-asset-value-copy.ts"),
  "utf8",
);
for (const phrase of [
  "private evidence trail",
  "hard to rebuild",
  "history your future beliefs",
]) {
  if (!copy.includes(phrase)) fail(`copy missing: ${phrase}`);
}

const card = fs.readFileSync(path.join(ROOT, "components/archive/ArchiveAssetCard.tsx"), "utf8");
if (!card.includes("trackArchiveAssetCardSeen")) fail("must track seen");

const events = fs.readFileSync(
  path.join(ROOT, "lib/metrics/archive-asset-value-events.ts"),
  "utf8",
);
for (const name of ["archive_asset_card_seen", "archive_asset_export_clicked"]) {
  if (!events.includes(name)) fail(`event missing: ${name}`);
}

for (const rel of ["app/memory/page.tsx", "app/account/page.tsx", "app/export/page.tsx", "app/pricing/PricingPageClient.tsx"]) {
  if (!fs.readFileSync(path.join(ROOT, rel), "utf8").includes("ArchiveAssetCard")) {
    fail(`${rel} must render ArchiveAssetCard`);
  }
}

if (failures.length) {
  console.error("validate-archive-asset-value failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-archive-asset-value ok");
