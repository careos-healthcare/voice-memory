#!/usr/bin/env node
import { insertPricingCatalog } from "../lib/server/unit-economics-pricing-store.ts";
import { loadPricingCatalog } from "../lib/server/unit-economics-pricing-catalog.ts";

if (!process.env.DATABASE_URL?.trim()) {
  console.error("Pricing activation failed: DATABASE_URL is required.");
  process.exit(1);
}

try {
  const { catalog, metadata } = await loadPricingCatalog();
  const inserted = await insertPricingCatalog(catalog);
  console.log(JSON.stringify({
    ok: true,
    inserted,
    versionKey: catalog.versionKey,
    effectiveFrom: catalog.effectiveFrom.toISOString(),
    sourceAsOf: metadata.source.asOf,
    lineCount: catalog.lines.length,
  }));
} catch {
  console.error("Pricing activation failed: catalog validation or insertion failed.");
  process.exit(1);
}
