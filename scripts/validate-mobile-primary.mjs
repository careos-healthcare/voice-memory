#!/usr/bin/env node
/**
 * Mobile primary distribution readiness — Flutter + static checks.
 */
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const MOBILE = path.join(ROOT, "apps/voicememory_mobile");
const failures = [];
const warnings = [];

function fail(msg) {
  failures.push(msg);
}

function warn(msg) {
  warnings.push(msg);
}

function read(rel) {
  return fs.readFileSync(path.join(MOBILE, rel), "utf8");
}

function mustExist(rel) {
  if (!fs.existsSync(path.join(MOBILE, rel))) fail(`missing ${rel}`);
}

const requiredDocs = [
  "docs/MOBILE_PARITY_PLAN.md",
  "docs/IOS_RELEASE_CHECKLIST.md",
  "docs/ANDROID_RELEASE_CHECKLIST.md",
  "docs/MOBILE_BUILD_COMMANDS.md",
];

for (const d of requiredDocs) mustExist(d);

const router = read("lib/router/app_router.dart");
for (const route of ["/record", "/archive-belief", "/discover", "/account", "/blind-spots", "/updates"]) {
  if (!router.includes(route)) fail(`app_router missing ${route}`);
}
if (!router.includes("ArchiveBeliefScreen")) fail("app_router must use ArchiveBeliefScreen");

const archiveScreen = read("lib/screens/archive_belief_screen.dart");
for (const token of [
  "ArchiveBeliefHeaderMobile",
  "ArchiveProgressBarMobile",
  "ArchiveDetailDrawer",
  "EvidenceLockerCompact",
]) {
  if (!archiveScreen.includes(token)) fail(`archive_belief_screen missing ${token}`);
}
const discoverScreen = read("lib/screens/discover_screen.dart");
if (!discoverScreen.includes("ArchiveMobilePageTemplate")) {
  fail("discover_screen must use ArchiveMobilePageTemplate");
}
const mainShell = read("lib/widgets/main_shell.dart");
if (mainShell.includes("Journal") || mainShell.includes("Blind Spots")) {
  fail("mobile primary bottom nav must not include Journal or Blind Spots");
}
if (/internal|founder-test|debug\//i.test(router)) {
  fail("app_router must not include internal/founder/debug routes");
}

const config = read("lib/config/app_config.dart");
if (!config.includes("VOICE_MEMORY_API_BASE_URL")) {
  fail("app_config must use VOICE_MEMORY_API_BASE_URL dart-define");
}
if (/localhost.*release/i.test(config)) {
  fail("app_config must not hardcode localhost for release");
}

const paywallCopy = read("lib/billing/value_moment_paywall.dart");
for (const phrase of [
  "Keep the evolving archive alive",
  "Keep tracking my patterns",
  "ChatGPT can help with today's question",
]) {
  if (!paywallCopy.includes(phrase)) fail(`paywall copy missing: ${phrase}`);
}

const manifest = read("android/app/src/main/AndroidManifest.xml");
if (!manifest.includes("RECORD_AUDIO")) fail("Android RECORD_AUDIO missing");
if (!manifest.includes("INTERNET")) fail("Android INTERNET missing");

const plist = read("ios/Runner/Info.plist");
if (!plist.includes("NSMicrophoneUsageDescription")) fail("iOS mic description missing");
if (!plist.includes("ArchiveMe")) fail("iOS display name ArchiveMe missing");

const api = read("lib/api/api_client.dart");
for (const fn of [
  "sendAuthCode",
  "verifyAuthCode",
  "getSession",
  "signOut",
  "captureAttest",
  "postTranscribe",
  "postAnalyze",
  "listJournal",
  "createJournalEntry",
  "deleteJournalEntry",
  "exportJournal",
  "getEntitlements",
  "createCheckoutSession",
  "syncManifest",
  "syncPull",
  "health",
]) {
  if (!api.includes(fn)) fail(`api_client missing ${fn}`);
}

// Secret scan (mobile tree)
const secretPattern =
  /(sk_live_|sk_test_|whsec_|OPENAI_API_KEY\s*=|RESEND_API_KEY\s*=|STRIPE_SECRET)/;
function scanDir(dir) {
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    if (ent.name === "build" || ent.name === ".dart_tool") continue;
    const full = path.join(dir, ent.name);
    if (ent.isDirectory()) scanDir(full);
    else if (/\.(dart|yaml|plist|xml|kts|md)$/.test(ent.name)) {
      const text = fs.readFileSync(full, "utf8");
      if (secretPattern.test(text)) fail(`possible secret in ${full}`);
    }
  }
}
scanDir(MOBILE);

const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
if (!pkg.scripts?.["validate:mobile-primary"]) {
  fail("package.json missing validate:mobile-primary script");
}

// Flutter
const flutter = spawnSync("flutter", ["--version"], { encoding: "utf8" });
if (flutter.status !== 0) {
  warn("Flutter SDK not available — skipping flutter analyze/test");
} else {
  console.log("Running flutter analyze…");
  const analyze = spawnSync("flutter", ["analyze"], {
    cwd: MOBILE,
    encoding: "utf8",
  });
  const analyzeOut = `${analyze.stdout}\n${analyze.stderr}`;
  if (/^\s*error\s•/m.test(analyzeOut)) {
    fail(`flutter analyze reported errors:\n${analyzeOut}`);
  }
  console.log("Running flutter test…");
  const test = spawnSync("flutter", ["test"], { cwd: MOBILE, encoding: "utf8" });
  if (test.status !== 0) {
    fail(`flutter test failed:\n${test.stdout}\n${test.stderr}`);
  }
}

if (warnings.length) {
  console.warn("Warnings:\n", warnings.join("\n"));
}
if (failures.length) {
  console.error("validate-mobile-primary failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-mobile-primary ok");
