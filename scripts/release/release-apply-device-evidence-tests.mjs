#!/usr/bin/env node
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");

test("testflight smoke mode passes without purchase/restore when livePurchases=false", async () => {
  const {
    isTestflightSmokePassing,
    isTestflightProofPassing,
  } = await import(
    path.join(ROOT, "packages/shared/lib/mobile/store-distribution-verification.ts")
  );

  const smokeOnly = {
    success: true,
    build_uploaded: true,
    build_installed: true,
    onboarding_completed: true,
    record_completed: true,
    archive_viewed: true,
    purchase_completed: false,
    restore_completed: false,
    timestamp: "2026-08-12T20:00:00.000Z",
  };

  assert.equal(isTestflightSmokePassing(smokeOnly), true);
  assert.equal(isTestflightProofPassing(smokeOnly), false);
});

test("release:apply-device-evidence --dry-run exits 0", () => {
  const out = execSync("node scripts/release-apply-device-evidence.mjs --dry-run", {
    cwd: ROOT,
    encoding: "utf8",
  });
  assert.match(out, /Apply device evidence/);
  assert.match(out, /dry-run/);
  const manifest = fs.readFileSync(path.join(ROOT, "release/focused_beta_status.json"), "utf8");
  assert.doesNotMatch(manifest, /"status": "pass"\s*,\s*"recordedAt": "[^"]+"\s*,\s*"commitSha": "[^"]+"\s*,\s*"buildNumber": 48\s*,\s*"environment": "testflight-internal"\s*,\s*"evidencePath": "mobile\/evidence\/testflight_tested.json"/);
});
