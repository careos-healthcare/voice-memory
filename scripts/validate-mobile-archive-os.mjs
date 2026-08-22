#!/usr/bin/env node
/**
 * Mobile Archive OS v1
 */
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const MOBILE = path.join(ROOT, "apps/mobile");
const failures = [];

function fail(msg) {
  failures.push(msg);
}

function read(rel) {
  return fs.readFileSync(path.join(MOBILE, rel), "utf8");
}

function mustExist(rel) {
  if (!fs.existsSync(path.join(MOBILE, rel))) fail(`missing ${rel}`);
}

for (const rel of [
  "lib/widgets/archive_detail_drawer.dart",
  "lib/widgets/archive_progress_bar_mobile.dart",
  "lib/features/archive_maturity/archive_maturity_engine.dart",
]) {
  mustExist(rel);
}
if (!fs.existsSync(path.join(ROOT, "scripts/validate-mobile-archive-os.mjs"))) {
  fail("missing scripts/validate-mobile-archive-os.mjs at repo root");
}

const mainShell = read("lib/widgets/main_shell.dart");
const destCount = (mainShell.match(/NavigationDestination/g) ?? []).length;
if (destCount !== 4) {
  fail(`main_shell must have exactly 4 NavigationDestination (found ${destCount})`);
}
for (const label of ["Record", "Archive", "Changes", "Account"]) {
  if (!mainShell.includes(`label: '${label}'`)) {
    fail(`main_shell missing tab label: ${label}`);
  }
}
for (const banned of ["Journal", "Search", "Discover", "Blind Spots", "Theory", "Insight"]) {
  if (mainShell.includes(`label: '${banned}'`) || mainShell.includes(`label: "${banned}"`)) {
    fail(`main_shell must not include fifth tab: ${banned}`);
  }
}

const router = read("lib/router/app_router.dart");
if (!router.includes("initialLocation: '/archive-belief'")) {
  fail("app_router initialLocation must be /archive-belief");
}
if (!router.includes("state.uri.path == '/record'")) {
  fail("app_router must redirect returning users from /record to archive");
}
if (!read("lib/screens/archive_belief_screen.dart").includes("ArchiveDetailDrawer")) {
  fail("archive screen must use ArchiveDetailDrawer");
}

const drawer = read("lib/widgets/archive_detail_drawer.dart");
for (const item of [
  "Search",
  "Belief Survival",
  "Accuracy",
  "Contradictions",
  "Reflection Log",
  "Pattern Review",
]) {
  if (!drawer.includes(item)) fail(`ArchiveDetailDrawer missing: ${item}`);
}

const archiveScreen = read("lib/screens/archive_belief_screen.dart");
const beliefIdx = archiveScreen.indexOf("_sectionLabel('Belief')");
const trustIdx = archiveScreen.indexOf("_sectionLabel('Trust')");
const changeIdx = archiveScreen.indexOf("_sectionLabel('Change')");
const progressIdx = archiveScreen.indexOf("_sectionLabel('Progress')");
const evidenceIdx = archiveScreen.indexOf("_sectionLabel('Evidence')");
const order = [beliefIdx, trustIdx, changeIdx, progressIdx, evidenceIdx];
if (order.some((i) => i < 0)) {
  fail("archive screen missing Belief/Trust/Change/Progress/Evidence sections");
}
for (let i = 1; i < order.length; i++) {
  if (order[i - 1] >= order[i]) {
    fail("archive screen section order must be Belief → Trust → Change → Progress → Evidence");
  }
}
for (const demoted of [
  "ArchiveQuickExplainCard",
  "ProtectArchiveBanner",
  "ArchiveWorthStatement",
  "ArchiveValueBanner",
  "context.push('/archive-detail')",
]) {
  if (archiveScreen.includes(demoted)) {
    fail(`archive screen must not prominently show: ${demoted}`);
  }
}
if (!archiveScreen.includes("ArchiveProgressBarMobile")) {
  fail("archive screen must include ArchiveProgressBarMobile");
}

const maturity = read("lib/features/archive_maturity/archive_maturity_engine.dart");
if (!maturity.includes("harder to fool")) {
  fail("ArchiveMaturityEngine must define harder-to-fool headline");
}
if (!read("lib/widgets/archive_progress_bar_mobile.dart").includes("view.headline")) {
  fail("ArchiveProgressBarMobile must render maturity headline");
}

const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
if (!pkg.scripts["validate:mobile-archive-os"]) {
  fail("package.json missing validate:mobile-archive-os script");
}

const flutter = spawnSync("flutter", ["--version"], { encoding: "utf8" });
if (flutter.status !== 0) {
  fail("Flutter SDK not available");
} else {
  console.log("Running flutter analyze…");
  const analyze = spawnSync("flutter", ["analyze"], { cwd: MOBILE, encoding: "utf8" });
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

if (failures.length) {
  console.error("validate-mobile-archive-os failed:\n");
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log("validate-mobile-archive-os passed");
