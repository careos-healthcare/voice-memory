#!/usr/bin/env node
import assert from "node:assert/strict";

import { entitlementsForTier, FREE_ARCHIVE_LIMIT } from "../lib/entitlement/tiers.ts";
import {
  getPaymentStackAudit,
  isLiveBillingAvailable,
} from "../lib/entitlement/payment-stack.ts";
import { entriesForResurfacingScope } from "../lib/entitlement/resurfacing-scope.ts";

const audit = getPaymentStackAudit();
assert.equal(audit.checkoutImplemented, false);
assert.equal(isLiveBillingAvailable(), false);

const free = entitlementsForTier("free");
assert.ok(free.includes("local_recording"));
assert.ok(free.includes("limited_archive"));
assert.ok(free.includes("basic_resurfacing"));
assert.equal(free.includes("open_loops"), false);
assert.equal(free.includes("export_reports"), false);

const pro = entitlementsForTier("pro");
assert.ok(pro.includes("unlimited_archive"));
assert.ok(pro.includes("open_loops"));
assert.ok(pro.includes("export_reports"));
assert.ok(pro.includes("encrypted_backup"));
assert.ok(pro.includes("deeper_resurfacing"));

const entries = Array.from({ length: 12 }, (_, i) => ({
  id: `e-${i}`,
  createdAt: new Date(2026, 0, 12 - i).toISOString(),
  transcript: "test",
  reflection: {
    mood: "",
    emotionalIntensity: 0,
    recurringThemes: [],
    hiddenConcern: "",
    positiveSignal: "",
    recommendation: "",
  },
  durationSeconds: 1,
}));

const scoped = entriesForResurfacingScope(entries);
assert.equal(scoped.length, FREE_ARCHIVE_LIMIT);

console.log("All entitlement tests passed.");
