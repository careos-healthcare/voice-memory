/**
 * Focused-beta final gate — automated check definitions (Sections A–D).
 * Manual Section E gates are validated but not executed here.
 */
import fs from "node:fs";
import path from "node:path";
import { execSync } from "node:child_process";
import {
  ROOT,
  PUBSPEC_PATH,
  NON_WAIVABLE_GATE_IDS,
  readGitHead,
  readPubspecIdentity,
} from "./focused-beta-core.mjs";

export const EVIDENCE_DIR = path.join(ROOT, "release/evidence");

/** @typedef {{ id: string, section: string, title: string, required: boolean, conditionalOn: string|null, automated: boolean, actor: { type: string, name: string } }} GateDefinition */

/** @type {GateDefinition[]} */
export const GATE_DEFINITIONS = [
  {
    id: "a_production_graph_analyzer",
    section: "A",
    title: "Production graph analyzer (zero errors/warnings)",
    required: true,
    conditionalOn: null,
    automated: true,
    actor: { type: "tool", name: "bash apps/mobile/tool/analyze_production_graph.sh" },
  },
  {
    id: "a_route_cta_integrity",
    section: "A",
    title: "No active CTA to disallowed route",
    required: true,
    conditionalOn: null,
    automated: true,
    actor: { type: "tool", name: "validate_production_route_links + validate_production_billing_absence" },
  },
  {
    id: "a_customer_language",
    section: "A",
    title: "No prohibited customer copy in production graph",
    required: true,
    conditionalOn: null,
    automated: true,
    actor: { type: "tool", name: "flutter test customer_language_production_copy_test.dart" },
  },
  {
    id: "log_redaction",
    section: "A",
    title: "Log redaction / privacy log scan",
    required: true,
    conditionalOn: null,
    automated: true,
    actor: { type: "tool", name: "npm run validate:privacy-logs" },
  },
  {
    id: "sensitive_storage_scan",
    section: "A",
    title: "No personal-content persistence in plaintext preferences",
    required: true,
    conditionalOn: null,
    automated: true,
    actor: { type: "tool", name: "flutter test storage/mobile_prefs_policy_test.dart" },
  },
  {
    id: "a_disabled_capability_imports",
    section: "A",
    title: "No production import/init of disabled billing/widgets/notifications/experiments",
    required: true,
    conditionalOn: null,
    automated: true,
    actor: { type: "tool", name: "bash apps/mobile/tool/validate_v1_production_graph.sh" },
  },
  {
    id: "remote_consent_no_network_evidence",
    section: "B",
    title: "Zero network after consent decline/revoke",
    required: true,
    conditionalOn: null,
    automated: true,
    actor: {
      type: "tool",
      name: "flutter test remote_processing_consent + capture_pipeline_consent_boundary",
    },
  },
  {
    id: "b_capture_archive_behavior",
    section: "B",
    title: "Capture, archive, evidence, export/delete automated behavior",
    required: true,
    conditionalOn: null,
    automated: true,
    actor: { type: "tool", name: "apps/mobile/tool/focused_beta_behavior_tests.txt" },
  },
  {
    id: "export_delete",
    section: "B",
    title: "Export and delete account paths",
    required: true,
    conditionalOn: null,
    automated: true,
    actor: {
      type: "tool",
      name: "flutter test archive_export_pack_test.dart + delete_account_confirmation_test.dart",
    },
  },
  {
    id: "c_android_release_build",
    section: "C",
    title: "Android release build",
    required: true,
    conditionalOn: null,
    automated: true,
    actor: { type: "tool", name: "flutter build apk --release" },
  },
  {
    id: "c_ios_release_build",
    section: "C",
    title: "iOS release build (no codesign)",
    required: true,
    conditionalOn: null,
    automated: true,
    actor: { type: "tool", name: "flutter build ios --release --no-codesign" },
  },
  {
    id: "c_web_release_build",
    section: "C",
    title: "Web lint / typecheck / test / build",
    required: true,
    conditionalOn: null,
    automated: true,
    actor: { type: "tool", name: "npm run lint/build/test -w @voice-memory/web" },
  },
  {
    id: "security_validators",
    section: "C",
    title: "Security validators against current routes",
    required: true,
    conditionalOn: null,
    automated: true,
    actor: {
      type: "tool",
      name: "validate:privacy-logs + validate:security-aplus + security_release_check",
    },
  },
  {
    id: "d_artifact_inspection",
    section: "D",
    title: "Artifact inspection (manifest, entitlements, SDK init, version, legal links)",
    required: true,
    conditionalOn: null,
    automated: true,
    actor: { type: "tool", name: "dart run tool/inspect_release_artifact.dart" },
  },
  {
    id: "e_manual_resilience_checklist",
    section: "E",
    title: "Manual resilience checklist (interrupt, offline, low storage, background kill)",
    required: true,
    conditionalOn: null,
    automated: false,
    actor: { type: "manual", name: "release/MANUAL_EVIDENCE_CHECKLIST.md" },
  },
  {
    id: "voiceover_talkback_manual",
    section: "E",
    title: "VoiceOver / TalkBack critical journeys",
    required: true,
    conditionalOn: null,
    automated: false,
    actor: { type: "manual", name: "apps/mobile/docs/ACCESSIBILITY_MANUAL_CHECKLIST.md" },
  },
  {
    id: "testflight_internal_smoke",
    section: "E",
    title: "TestFlight / Play internal install smoke",
    required: true,
    conditionalOn: null,
    automated: false,
    actor: { type: "manual", name: "npm run validate:testflight-proof" },
  },
  {
    id: "ios_android_build_signing",
    section: "E",
    title: "iOS / Android build signing evidence",
    required: true,
    conditionalOn: null,
    automated: false,
    actor: { type: "manual", name: "npm run validate:ios-signing && validate:android-signing" },
  },
  {
    id: "sync_offline_conflict",
    section: "E",
    title: "Sync / offline / conflict resolution",
    required: true,
    conditionalOn: "sync",
    automated: false,
    actor: { type: "tool", name: "npm run validate:offline-sync-production" },
  },
  {
    id: "purchase_restore",
    section: "E",
    title: "Purchase / restore (when billing enabled)",
    required: true,
    conditionalOn: "storeBilling",
    automated: false,
    actor: { type: "manual", name: "validate:revenuecat-production + device purchase smoke" },
  },
  {
    id: "notifications_push",
    section: "E",
    title: "Push / local notifications",
    required: true,
    conditionalOn: "notifications",
    automated: false,
    actor: { type: "tool", name: "V1CapabilityRegistry.notifications" },
  },
  {
    id: "native_extensions_widgets",
    section: "E",
    title: "Native extensions / home-screen widgets",
    required: true,
    conditionalOn: "nativeExtensions",
    automated: false,
    actor: { type: "tool", name: "V1CapabilityRegistry.nativeExtensions" },
  },
];

export const REQUIRED_GATE_IDS = GATE_DEFINITIONS.map((g) => g.id);

const MOBILE = path.join(ROOT, "apps/mobile");
const WEB = path.join(ROOT, "apps/web");

/** Strip flutter/dart dependency-resolution noise from captured stdout. */
export function sanitizeGateOutput(output) {
  if (!output) return "";
  const lines = output.split("\n");
  const kept = [];
  let skippingPubGet = false;

  for (const line of lines) {
    const trimmed = line.trim();
    if (
      trimmed === "Resolving dependencies..." ||
      trimmed === "Downloading packages..." ||
      trimmed.startsWith("Running build hooks")
    ) {
      skippingPubGet = true;
      continue;
    }
    if (skippingPubGet) {
      if (trimmed === "Got dependencies!") {
        skippingPubGet = false;
        continue;
      }
      if (/^\d+ packages have newer versions/.test(trimmed)) continue;
      if (trimmed.startsWith("Try `flutter pub outdated`")) continue;
      if (/^  \S+ .+ available\)?$/.test(line)) continue;
      // Test/build output ended the pub-get block.
      if (
        /^\d{2}:\d{2} \+\d+/.test(trimmed) ||
        /^(All tests passed|Some tests failed)/.test(trimmed) ||
        /^[a-z_].*: (PASS|FAIL)/.test(trimmed) ||
        trimmed.startsWith("OK —") ||
        trimmed.startsWith("==>")
      ) {
        skippingPubGet = false;
        kept.push(line);
      }
      continue;
    }
    kept.push(line);
  }

  return kept
    .join("\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

/** Summarize gate output for manifest notes — never lead with pub-get noise. */
export function summarizeGateNotes(output, maxLines = 12) {
  const cleaned = sanitizeGateOutput(output);
  const lines = cleaned.split("\n").filter((l) => l.trim().length > 0);
  if (lines.length === 0) return cleaned || "exit 0";

  const summaryIdx = lines.findIndex((l) =>
    /All tests passed!|Some tests failed|Failing tests:|^FAIL \(|: PASS$|: FAIL \(/i.test(l),
  );
  if (summaryIdx >= 0) {
    const start = Math.max(0, summaryIdx - 2);
    return lines.slice(start, summaryIdx + 1).join("\n");
  }

  const testProgress = lines.filter((l) => /^\d{2}:\d{2} \+\d+/.test(l.trim()));
  if (testProgress.length > 0) {
    return testProgress.slice(-Math.min(3, testProgress.length)).join("\n");
  }

  if (lines.length <= maxLines) return lines.join("\n");
  return [
    ...lines.slice(0, 2),
    `… (${lines.length - maxLines} more lines)`,
    ...lines.slice(-(maxLines - 3)),
  ].join("\n");
}

let mobileDepsReady = false;

/** Run pub get once before flutter test invocations (--no-pub on each test). */
export function ensureMobileFlutterDeps(force = false) {
  if (mobileDepsReady && !force) return { ok: true, output: "flutter pub get: skipped (already ran)\n" };
  const result = run("flutter pub get", { cwd: MOBILE, timeoutMs: 300_000 });
  if (result.ok) mobileDepsReady = true;
  return result;
}

/** Reset dep cache — for tests only. */
export function resetMobileDepsCacheForTest() {
  mobileDepsReady = false;
}

function ensureEvidenceDir() {
  fs.mkdirSync(EVIDENCE_DIR, { recursive: true });
}

/** @param {string} id @param {string} output */
function writeEvidence(id, output) {
  ensureEvidenceDir();
  const file = path.join(EVIDENCE_DIR, `gate_${id}.log`);
  fs.writeFileSync(file, output);
  return path.relative(ROOT, file);
}

/**
 * @param {string} cmd
 * @param {{ cwd?: string, timeoutMs?: number }} [opts]
 */
function run(cmd, opts = {}) {
  const cwd = opts.cwd ?? ROOT;
  const timeoutMs = opts.timeoutMs ?? 600_000;
  try {
    const output = execSync(cmd, {
      cwd,
      encoding: "utf8",
      stdio: "pipe",
      timeout: timeoutMs,
      maxBuffer: 20 * 1024 * 1024,
    });
    return { ok: true, output: sanitizeGateOutput(output ?? "") };
  } catch (e) {
    const stdout = sanitizeGateOutput(e.stdout?.toString() ?? "");
    const stderr = sanitizeGateOutput(e.stderr?.toString() ?? "");
    return {
      ok: false,
      output: [stdout, stderr, e.message].filter(Boolean).join("\n"),
      exitCode: e.status ?? 1,
    };
  }
}

/** @param {string} gateId */
export function runAutomatedCheck(gateId) {
  switch (gateId) {
    case "a_production_graph_analyzer":
      return run("bash tool/analyze_production_graph.sh", { cwd: MOBILE });

    case "a_route_cta_integrity": {
      const links = run("dart run tool/validate_production_route_links.dart", { cwd: MOBILE });
      if (!links.ok) return links;
      const billing = run("dart run tool/validate_production_billing_absence.dart", {
        cwd: MOBILE,
      });
      return {
        ok: billing.ok,
        output: `${links.output}\n${billing.output}`,
      };
    }

    case "a_customer_language":
      ensureMobileFlutterDeps();
      return run("flutter test --no-pub test/customer_language_production_copy_test.dart", {
        cwd: MOBILE,
        timeoutMs: 300_000,
      });

    case "log_redaction":
      return run("npm run validate:privacy-logs", { cwd: ROOT });

    case "sensitive_storage_scan":
      ensureMobileFlutterDeps();
      return run("flutter test --no-pub test/storage/mobile_prefs_policy_test.dart", {
        cwd: MOBILE,
        timeoutMs: 120_000,
      });

    case "a_disabled_capability_imports":
      return run("bash tool/validate_v1_production_graph.sh", { cwd: MOBILE });

    case "remote_consent_no_network_evidence":
      ensureMobileFlutterDeps();
      return run(
        "flutter test --no-pub test/remote_processing_consent_gate_test.dart test/capture_pipeline_consent_boundary_test.dart test/security/remote_processing_consent_gate_test.dart",
        { cwd: MOBILE, timeoutMs: 300_000 },
      );

    case "b_capture_archive_behavior": {
      ensureMobileFlutterDeps();
      const listPath = path.join(MOBILE, "tool/focused_beta_behavior_tests.txt");
      const tests = fs
        .readFileSync(listPath, "utf8")
        .split("\n")
        .map((l) => l.trim())
        .filter(Boolean);
      return run(`flutter test --no-pub ${tests.join(" ")}`, {
        cwd: MOBILE,
        timeoutMs: 900_000,
      });
    }

    case "export_delete":
      ensureMobileFlutterDeps();
      return run(
        "flutter test --no-pub test/archive_export_pack_test.dart test/delete_account_confirmation_test.dart",
        { cwd: MOBILE, timeoutMs: 300_000 },
      );

    case "c_android_release_build":
      return run("flutter build apk --release", {
        cwd: MOBILE,
        timeoutMs: 900_000,
      });

    case "c_ios_release_build":
      return run("flutter build ios --release --no-codesign", {
        cwd: MOBILE,
        timeoutMs: 900_000,
      });

    case "c_web_release_build": {
      const lint = run("npm run lint", { cwd: WEB, timeoutMs: 300_000 });
      if (!lint.ok) return lint;
      const test = run("npm run test", { cwd: WEB, timeoutMs: 300_000 });
      if (!test.ok) return test;
      return run("npm run build", { cwd: WEB, timeoutMs: 600_000 });
    }

    case "security_validators": {
      const privacy = run("npm run validate:privacy-logs", { cwd: ROOT });
      if (!privacy.ok) return privacy;
      const aplus = run("npm run validate:security-aplus", { cwd: ROOT });
      if (!aplus.ok) return aplus;
      const mobile = run("dart run tool/security_release_check.dart", { cwd: MOBILE });
      return mobile;
    }

    case "d_artifact_inspection":
      return run("dart run tool/inspect_release_artifact.dart", { cwd: MOBILE });

    default:
      return { ok: false, output: `No automated runner for gate ${gateId}` };
  }
}

/** @returns {{ semanticVersion: string, buildNumber: number, commitSha: string }} */
export function readCurrentIdentity() {
  const pubspec = readPubspecIdentity(PUBSPEC_PATH);
  const commitSha = readGitHead(true);
  if (!commitSha) {
    throw new Error("Could not read git HEAD for release identity");
  }
  return {
    semanticVersion: pubspec.semanticVersion,
    buildNumber: pubspec.buildNumber,
    commitSha,
  };
}

export function summarizeOutput(output, maxLines = 12) {
  return summarizeGateNotes(output, maxLines);
}

export { writeEvidence };
