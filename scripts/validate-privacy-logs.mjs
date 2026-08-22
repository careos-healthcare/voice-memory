#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { execSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const BANNED_PATTERNS = [
  {
    re: /console\.(log|info|error|warn)\([^)]*\btranscript\b/i,
    msg: "raw transcript in console",
  },
  { re: /logServerEvent\([^)]*transcript/i, msg: "transcript in structured log fields" },
  { re: /sk_live_[a-zA-Z0-9]+/, msg: "possible live Stripe secret in source" },
  { re: /whsec_[a-zA-Z0-9]{20,}/, msg: "possible webhook secret in source" },
  { re: /Bearer\s+[a-zA-Z0-9._-]{20,}/, msg: "possible bearer token literal" },
];

// `apps/web/app/api` has not existed since the API moved to its own workspace,
// and `walk()` returns [] for a missing directory — so every API route was
// silently exempt from the banned-pattern scan below.
const SCAN_DIRS = ["apps/api/app/api", "packages/shared/lib/server", "packages/shared/lib/billing", "packages/shared/lib/persistence"];

function walk(dir, files = []) {
  if (!fs.existsSync(dir)) return files;
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, ent.name);
    if (ent.isDirectory()) walk(p, files);
    else if (/\.(ts|tsx|mjs)$/.test(ent.name)) files.push(p);
  }
  return files;
}

let scannedFileCount = 0;

for (const sub of SCAN_DIRS) {
  const dir = path.join(ROOT, sub);
  if (!fs.existsSync(dir)) {
    failures.push(`scan directory ${sub} does not exist — this scan cannot be enforced`);
    continue;
  }
  for (const file of walk(dir)) {
    scannedFileCount += 1;
    const text = fs.readFileSync(file, "utf8");
    if (/log\s*\(\s*\{[^}]*\bemail\s*:\s*session\.email/.test(text)) {
      failures.push(`${file}: logs raw email (use emailHash)`);
    }
    for (const { re, msg } of BANNED_PATTERNS) {
      if (re.test(text)) failures.push(`${file}: ${msg}`);
    }
  }
}

// Every directory can exist and still hold no matching file, which would report
// a clean scan of nothing. An empty scan set is a broken gate, not a clean one.
if (scannedFileCount === 0) {
  failures.push(
    `scanned 0 files across ${SCAN_DIRS.length} scan directories — the gate is not enforcing anything`,
  );
}

const structured = fs.readFileSync(path.join(ROOT, "packages/shared/lib/server/structured-log.ts"), "utf8");
const sanitizer = fs.readFileSync(path.join(ROOT, "packages/shared/lib/server/log-sanitizer.ts"), "utf8");
if (!structured.includes("sanitizeLogRecord")) failures.push("structured-log missing sanitizeLogRecord");
if (!sanitizer.includes("raw_text")) failures.push("log-sanitizer missing raw_text redaction");
if (!sanitizer.includes("citedEntryIds")) failures.push("log-sanitizer missing citedEntryIds redaction");

// The runner path is asserted here and cross-checked against the Dart test that
// invokes it. A previous bulk move of 101 files into `tool/archive/` left both
// callers pointing at a path that no longer existed, so the only check on
// transcripts and bearer tokens reaching mobile logs went unenforced in CI and
// in the test suite at the same time. Drift between the two must fail loudly.
const MOBILE_DIR = path.join(ROOT, "apps/mobile");
const MOBILE_RUNNER_REL = "tool/validate_mobile_privacy_logs.dart";
const MOBILE_RUNNER_TEST_REL = "test/security/release_log_scan_test.dart";

const mobileValidator = path.join(MOBILE_DIR, MOBILE_RUNNER_REL);
const mobileValidatorTest = path.join(MOBILE_DIR, MOBILE_RUNNER_TEST_REL);

if (!fs.existsSync(mobileValidator)) {
  failures.push(`apps/mobile/${MOBILE_RUNNER_REL} missing`);
} else {
  if (!fs.existsSync(mobileValidatorTest)) {
    failures.push(`apps/mobile/${MOBILE_RUNNER_TEST_REL} missing — the mobile scan has no test-suite caller`);
  } else if (!fs.readFileSync(mobileValidatorTest, "utf8").includes(MOBILE_RUNNER_REL)) {
    failures.push(
      `apps/mobile/${MOBILE_RUNNER_TEST_REL} no longer invokes ${MOBILE_RUNNER_REL} — callers have drifted from the runner`,
    );
  }

  let hasDart = true;
  try {
    execSync("dart --version", { stdio: "ignore" });
  } catch {
    hasDart = false;
  }

  if (hasDart) {
    // `dart run` performs an implicit `pub get` when pubspec.yaml is newer than
    // the resolved package config, which would rewrite pubspec.lock from a
    // read-only gate. Pin the existing config when one is present.
    const packageConfig = path.join(MOBILE_DIR, ".dart_tool/package_config.json");
    const command = fs.existsSync(packageConfig)
      ? `dart --packages=.dart_tool/package_config.json ${MOBILE_RUNNER_REL}`
      : `dart run ${MOBILE_RUNNER_REL}`;
    try {
      execSync(command, { cwd: MOBILE_DIR, stdio: "pipe" });
    } catch (e) {
      const detail = [e.stdout, e.stderr]
        .map((chunk) => chunk?.toString().trim() ?? "")
        .filter(Boolean)
        .join("\n");
      failures.push(`mobile privacy log validator failed:\n${detail || e.message}`);
    }
  } else {
    // server-gates runs on a node-only runner with no Dart SDK, so the scan
    // itself cannot execute here. Say so out loud — a skipped check and a
    // passing check must not look the same.
    console.log(
      `validate-privacy-logs: SKIPPED mobile scan — no Dart SDK on this runner. ` +
        `Wiring for ${MOBILE_RUNNER_REL} was verified, but the banned-pattern scan did NOT run here. ` +
        `It executes only where a Dart SDK is present, via ${MOBILE_RUNNER_TEST_REL}.`,
    );
  }
}

if (failures.length) {
  console.error("validate-privacy-logs failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-privacy-logs ok");
