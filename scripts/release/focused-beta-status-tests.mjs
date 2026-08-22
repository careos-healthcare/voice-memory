#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
import {
  MANIFEST_PATH,
  evaluateGate,
  evaluateRelease,
  generateReleaseSummary,
  loadManifest,
  validateManifestSchema,
  writeGeneratedDocs,
} from "./focused-beta-core.mjs";
import {
  sanitizeGateOutput,
  summarizeGateNotes,
} from "./focused-beta-gate-checks.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const FIXTURES = path.join(__dirname, "fixtures");

function cloneManifest() {
  return JSON.parse(fs.readFileSync(MANIFEST_PATH, "utf8"));
}

function withTempManifest(mutator) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "focused-beta-"));
  const manifestPath = path.join(dir, "focused_beta_status.json");
  const manifest = cloneManifest();
  mutator(manifest);
  fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
  return { dir, manifestPath, manifest };
}

test("schema validates production manifest", () => {
  const manifest = loadManifest();
  const result = validateManifestSchema(manifest);
  assert.equal(result.valid, true, result.errors.join("\n"));
});

test("pass gate with aligned identity is not blocked", () => {
  const manifest = cloneManifest();
  const identity = manifest.identity;
  const gate = manifest.gates.find((g) => g.id === "log_redaction");
  gate.status = "pass";
  gate.commitSha = identity.commitSha;
  gate.buildNumber = identity.buildNumber;
  gate.recordedAt = identity.createdAt;
  gate.evidencePath = "docs/release/BASELINE_2026-08-12.md";
  const blockers = evaluateGate(gate, identity, manifest.capabilities, {
    now: identity.createdAt,
    headSha: identity.commitSha,
  });
  assert.equal(blockers.length, 0);
});

test("fail gate blocks release", () => {
  const manifest = cloneManifest();
  const result = evaluateRelease(manifest, {
    now: manifest.identity.createdAt,
    headSha: manifest.identity.commitSha,
  });
  assert.equal(result.releaseAllowed, false);
  assert.ok(result.blockers.some((b) => b.gateId === "testflight_internal_smoke"));
});

test("stale pass gate blocks release", () => {
  const manifest = cloneManifest();
  const gate = manifest.gates.find((g) => g.id === "log_redaction");
  gate.status = "pass";
  gate.commitSha = manifest.identity.commitSha;
  gate.buildNumber = manifest.identity.buildNumber;
  gate.recordedAt = "2020-01-01T00:00:00.000Z";
  const blockers = evaluateGate(gate, manifest.identity, manifest.capabilities, {
    now: manifest.identity.createdAt,
    headSha: manifest.identity.commitSha,
  });
  assert.ok(blockers.some((b) => b.reason.includes("stale")));
});

test("build-mismatched pass gate blocks release", () => {
  const manifest = cloneManifest();
  const gate = manifest.gates.find((g) => g.id === "log_redaction");
  gate.status = "pass";
  gate.commitSha = manifest.identity.commitSha;
  gate.buildNumber = manifest.identity.buildNumber - 1;
  gate.recordedAt = manifest.identity.createdAt;
  gate.evidencePath = "docs/release/BASELINE_2026-08-12.md";
  const blockers = evaluateGate(gate, manifest.identity, manifest.capabilities, {
    now: manifest.identity.createdAt,
    headSha: manifest.identity.commitSha,
  });
  assert.ok(blockers.some((b) => b.reason.includes("build mismatch")));
});

test("commit-mismatched pass gate blocks release", () => {
  const manifest = cloneManifest();
  const gate = manifest.gates.find((g) => g.id === "log_redaction");
  gate.status = "pass";
  gate.commitSha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
  gate.buildNumber = manifest.identity.buildNumber;
  gate.recordedAt = manifest.identity.createdAt;
  gate.evidencePath = "docs/release/BASELINE_2026-08-12.md";
  const blockers = evaluateGate(gate, manifest.identity, manifest.capabilities, {
    now: manifest.identity.createdAt,
    headSha: manifest.identity.commitSha,
  });
  assert.ok(blockers.some((b) => b.reason.includes("commit mismatch")));
});

test("missing evidence path blocks pass gate", () => {
  const manifest = cloneManifest();
  const gate = manifest.gates.find((g) => g.id === "log_redaction");
  gate.status = "pass";
  gate.commitSha = manifest.identity.commitSha;
  gate.buildNumber = manifest.identity.buildNumber;
  gate.recordedAt = manifest.identity.createdAt;
  gate.evidencePath = "release/does-not-exist.md";
  const blockers = evaluateGate(gate, manifest.identity, manifest.capabilities, {
    now: manifest.identity.createdAt,
    headSha: manifest.identity.commitSha,
  });
  assert.ok(blockers.some((b) => b.reason.includes("missing evidence")));
});

test("expired waiver blocks waived gate", () => {
  const manifest = cloneManifest();
  const gate = manifest.gates.find((g) => g.id === "notifications_push");
  gate.waiver.expiresAt = "2020-01-01T00:00:00.000Z";
  const blockers = evaluateGate(gate, manifest.identity, manifest.capabilities, {
    now: manifest.identity.createdAt,
    headSha: manifest.identity.commitSha,
  });
  assert.ok(blockers.some((b) => b.reason.includes("waiver expired")));
});

test("disabled capability skips conditional gate when waived", () => {
  const manifest = cloneManifest();
  const gate = manifest.gates.find((g) => g.id === "notifications_push");
  assert.equal(manifest.capabilities.notifications.enabled, false);
  assert.equal(gate.status, "waived");
  const blockers = evaluateGate(gate, manifest.identity, manifest.capabilities, {
    now: manifest.identity.createdAt,
    headSha: manifest.identity.commitSha,
  });
  assert.equal(blockers.length, 0);
});

test("sanitizeGateOutput strips flutter pub get noise before test output", () => {
  const noisy = [
    "Resolving dependencies...",
    "Downloading packages...",
    "  characters 1.4.0 (1.4.1 available)",
    "  meta 1.16.0 (1.17.0 available)",
    "Got dependencies!",
    "12 packages have newer versions incompatible with dependency constraints.",
    "Try `flutter pub outdated` for more information.",
    "00:00 +0: loading test/customer_language_production_copy_test.dart",
    "00:01 +3: All tests passed!",
  ].join("\n");

  const cleaned = sanitizeGateOutput(noisy);
  assert.doesNotMatch(cleaned, /Resolving dependencies/);
  assert.doesNotMatch(cleaned, /Downloading packages/);
  assert.match(cleaned, /00:00 \+0: loading/);
  assert.match(cleaned, /All tests passed!/);
});

test("summarizeGateNotes prefers test result lines over pub-get noise", () => {
  const noisy = [
    "Resolving dependencies...",
    "Downloading packages...",
    "Got dependencies!",
    "00:00 +0: loading test/storage/mobile_prefs_policy_test.dart",
    "00:01 +2: All tests passed!",
  ].join("\n");

  const notes = summarizeGateNotes(noisy);
  assert.doesNotMatch(notes, /Resolving dependencies/);
  assert.match(notes, /All tests passed!/);
});

test("generated markdown cannot override machine fail result", () => {
  const manifest = cloneManifest();
  manifest.gates.find((g) => g.id === "a_route_cta_integrity").status = "fail";
  const summary = generateReleaseSummary(manifest);
  assert.match(summary, /RELEASE BLOCKED/);
  assert.doesNotMatch(summary, /all tests passed/i);
  assert.doesNotMatch(summary, /RELEASE ALLOWED/);

  const fixturePath = path.join(FIXTURES, "contradictory_handwritten_summary.md");
  const handwritten = fs.readFileSync(fixturePath, "utf8");
  assert.match(handwritten, /all tests passed/i);
  assert.match(handwritten, /Ready for TestFlight/i);
  assert.doesNotMatch(summary, /all tests passed/i);
  assert.doesNotMatch(summary, /Ready for TestFlight upload/i);
  assert.ok(summary.includes("RELEASE BLOCKED"));
});

test("generated documents are deterministic", () => {
  const manifest = loadManifest();
  writeGeneratedDocs(manifest);
  const firstSummary = fs.readFileSync(path.join(path.dirname(MANIFEST_PATH), "../generated/release-summary.md"), "utf8");
  writeGeneratedDocs(manifest);
  const secondSummary = fs.readFileSync(path.join(path.dirname(MANIFEST_PATH), "../generated/release-summary.md"), "utf8");
  assert.equal(firstSummary, secondSummary);
});
