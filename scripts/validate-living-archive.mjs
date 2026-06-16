#!/usr/bin/env node
/**
 * Living Archive System v1 — archive feels alive (presentation only).
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];
const fail = (msg) => failures.push(msg);

function read(rel) {
  return fs.readFileSync(path.join(ROOT, rel), "utf8");
}

function mustExist(rel) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const required = [
  "types/living-archive.ts",
  "lib/archive/archive-status.ts",
  "lib/archive/archive-pulse.ts",
  "lib/archive/archive-memory.ts",
  "lib/archive/archive-open-question.ts",
  "lib/archive/archive-reason-to-return.ts",
  "lib/archive/archive-activity.ts",
  "lib/archive/living-archive.ts",
  "lib/archive/living-archive-copy.ts",
  "components/archive/ArchiveStatusCard.tsx",
  "components/archive/ArchivePulse.tsx",
  "components/archive/ArchiveMemoryCard.tsx",
  "components/archive/ArchiveOpenQuestion.tsx",
  "components/archive/ArchiveReasonToReturn.tsx",
  "components/archive/ArchiveActivityPanel.tsx",
  "apps/voicememory_mobile/lib/features/living_archive/living_archive_mobile.dart",
  "apps/voicememory_mobile/lib/widgets/archive_status_card_mobile.dart",
  "apps/voicememory_mobile/lib/widgets/archive_pulse_mobile.dart",
  "apps/voicememory_mobile/lib/widgets/archive_reason_to_return_mobile.dart",
];

for (const rel of required) mustExist(rel);

const statusLib = read("lib/archive/archive-status.ts");
for (const token of [
  "deriveArchiveLivingStatus",
  "buildArchiveStatusView",
  "learning",
  "investigating",
  "strengthening",
  "uncertain",
  "revising",
  "stable",
]) {
  if (!statusLib.includes(token)) fail(`archive-status missing ${token}`);
}

const copy = read("lib/archive/living-archive-copy.ts");
for (const token of [
  "ARCHIVE_STATUS_CARD_TITLE",
  "Status Changes",
  "Belief Changes",
  "Evidence Changes",
  "Open Questions",
]) {
  if (!copy.includes(token)) fail(`living-archive-copy missing ${token}`);
}

const home = read("components/archive/EvidenceArchiveHome.tsx");
const chromeStart = home.indexOf("const archiveBeliefChrome");
const chromeBlock =
  chromeStart >= 0 ? home.slice(chromeStart, chromeStart + 2500) : home;
const headerIdx = chromeBlock.indexOf("<ArchiveBeliefHeader");
const statusIdx = chromeBlock.indexOf("<ArchiveStatusCard");
const deltaIdx = chromeBlock.indexOf("<ArchiveStateDeltaSection");
const pulseIdx = chromeBlock.indexOf("<ArchivePulse");
const memoryIdx = chromeBlock.indexOf("<ArchiveMemoryCard");
const questionIdx = chromeBlock.indexOf("<ArchiveOpenQuestion");
const reasonIdx = chromeBlock.indexOf("<ArchiveReasonToReturn");

if (headerIdx < 0 || statusIdx < 0 || deltaIdx < 0 || pulseIdx < 0) {
  fail("EvidenceArchiveHome must wire belief, status, delta, pulse");
}
if (!(headerIdx < statusIdx && statusIdx < deltaIdx && deltaIdx < pulseIdx)) {
  fail("Archive home order: Belief → Status → Delta → Pulse");
}
if (memoryIdx < 0 || questionIdx < 0 || reasonIdx < 0) {
  fail("EvidenceArchiveHome must include memory, open questions, return reason");
}

const discover = read("app/discover/page.tsx");
if (!discover.includes("ArchiveActivityPanel")) {
  fail("discover must use ArchiveActivityPanel");
}
if (!discover.includes("ArchiveReasonToReturn")) {
  fail("discover must show ArchiveReasonToReturn");
}
if (discover.includes("TheoryChangeFeed") || discover.includes("ArchiveDiscoverDeltaFeed")) {
  fail("discover must not use feed cards or delta feed as primary activity");
}

const product = read("lib/product/archive-product-copy.ts");
if (!product.includes('"Archive Activity"')) {
  fail('discover product copy must frame as "Archive Activity"');
}

const activity = read("lib/archive/archive-activity.ts");
if (!activity.includes("evidence.movements")) {
  fail("archive-activity must read evidence feed movements");
}

const mobile = read("apps/voicememory_mobile/lib/screens/archive_belief_screen.dart");
const mHeader = mobile.indexOf("ArchiveBeliefHeaderMobile");
const mStatus = mobile.indexOf("ArchiveStatusCardMobile");
const mDelta = mobile.indexOf("ArchiveStateDeltaCardMobile");
const mPulse = mobile.indexOf("ArchivePulseMobile");
const mTrust = mobile.indexOf("_sectionLabel('Trust')");
const mEvidence = mobile.indexOf("_sectionLabel('Evidence')");

if (mHeader < 0 || mStatus < 0 || mDelta < 0 || mPulse < 0) {
  fail("mobile archive must include belief, status, delta, pulse");
}
if (!(mHeader < mStatus && mStatus < mDelta && mDelta < mPulse && mPulse < mTrust && mTrust < mEvidence)) {
  fail("mobile order: Belief → Status → Delta → Pulse → Trust → Evidence");
}
if (!mobile.includes("ArchiveReasonToReturnMobile")) {
  fail("mobile archive must show return reason");
}

const pkg = JSON.parse(read("package.json"));
if (!pkg.scripts?.["validate:living-archive"]) {
  fail("package.json missing validate:living-archive script");
}

if (failures.length) {
  console.error("validate-living-archive failed:\n");
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log("validate-living-archive ok");
