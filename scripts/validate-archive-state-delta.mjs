#!/usr/bin/env node
/**
 * Archive State Delta v1 — returning users see what changed within 5 seconds.
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
  "packages/shared/types/archive-state-snapshot.ts",
  "packages/shared/lib/archive/archive-state-snapshot.ts",
  "packages/shared/lib/archive/archive-state-delta-copy.ts",
  "apps/web/components/archive/ArchiveStateDeltaCard.tsx",
  "apps/web/components/archive/ArchiveStateDeltaSection.tsx",
  "apps/web/components/archive/ArchiveDiscoverDeltaFeed.tsx",
  "apps/mobile/lib/features/archive_state_delta/archive_state_snapshot.dart",
  "apps/mobile/lib/widgets/archive_state_delta_card_mobile.dart",
];

for (const rel of required) mustExist(rel);

const snapshot = read("packages/shared/lib/archive/archive-state-snapshot.ts");
for (const token of [
  "captureArchiveStateSnapshot",
  "buildArchiveStateDelta",
  "commitArchiveStateView",
  "buildArchiveDiscoverDeltaCollection",
  "belief",
  "confidence",
  "reputation",
  "evidenceCount",
  "lifeAreas",
  "timestamp",
]) {
  if (!snapshot.includes(token)) fail(`archive-state-snapshot missing ${token}`);
}

const card = read("apps/web/components/archive/ArchiveStateDeltaCard.tsx");
for (const token of ["Then", "Now", "row.difference", "data-testid=\"archive-state-delta-card\""]) {
  if (!card.includes(token)) fail(`ArchiveStateDeltaCard missing ${token}`);
}

const copy = read("packages/shared/lib/archive/archive-state-delta-copy.ts");
if (!copy.includes("Your archive changed while you were away.")) {
  fail("away return headline missing");
}
if (!copy.includes("What changed since you last looked")) {
  fail("delta title missing");
}

const home = read("apps/web/components/archive/EvidenceArchiveHome.tsx");
const chromeStart = home.indexOf("const archiveBeliefChrome");
const chromeBlock =
  chromeStart >= 0 ? home.slice(chromeStart, chromeStart + 2500) : home;
const headerIdx = chromeBlock.indexOf("<ArchiveBeliefHeader");
const statusIdx = chromeBlock.indexOf("<ArchiveStatusCard");
const deltaIdx = chromeBlock.indexOf("<ArchiveStateDeltaSection");
const healthIdx = chromeBlock.indexOf("<ArchiveHealthSummary");
if (headerIdx < 0 || statusIdx < 0 || deltaIdx < 0) {
  fail("EvidenceArchiveHome must include belief header, status, and state delta");
}
if (!(headerIdx < statusIdx && statusIdx < deltaIdx && deltaIdx < healthIdx)) {
  fail("Archive home order: Belief → Status → Delta → Health/Reputation stack");
}

const command = read("apps/web/components/archive/ArchiveCommandCenter.tsx");
const repIdx = command.indexOf('"reputation"');
const trustIdx = command.indexOf('"trust"');
const timelineIdx = command.indexOf('"timeline"');
const evidenceIdx = command.indexOf('"evidence"');
if (repIdx < 0 || trustIdx < 0 || timelineIdx < 0 || evidenceIdx < 0) {
  fail("ArchiveCommandCenter must include reputation, trust, timeline, evidence");
}
if (!(repIdx < trustIdx && trustIdx < timelineIdx && timelineIdx < evidenceIdx)) {
  fail("ArchiveCommandCenter order: reputation → trust → timeline → evidence");
}

const discover = read("apps/web/app/discover/page.tsx");
if (!discover.includes("ArchiveActivityPanel") && !discover.includes("ArchiveDiscoverDeltaFeed")) {
  fail("discover must use ArchiveActivityPanel or ArchiveDiscoverDeltaFeed");
}
if (discover.includes("SessionMovementSummary")) {
  fail("discover must not use SessionMovementSummary (delta ownership)");
}
if (discover.includes("ArchiveReputationMovement")) {
  fail("discover must not use ArchiveReputationMovement in changes section");
}

const mobile = read("apps/mobile/lib/screens/archive_belief_screen.dart");
const mobileHeader = mobile.indexOf("ArchiveBeliefHeaderMobile");
const mobileStatus = mobile.indexOf("ArchiveStatusCardMobile");
const mobileDelta = mobile.indexOf("ArchiveStateDeltaCardMobile");
const mobileTrust = mobile.indexOf("_sectionLabel('Trust')");
if (mobileHeader < 0 || mobileStatus < 0 || mobileDelta < 0) {
  fail("mobile archive must include belief header, status, and delta card");
}
if (!(mobileHeader < mobileStatus && mobileStatus < mobileDelta && mobileDelta < mobileTrust)) {
  fail("mobile order: Belief header → Status → Delta → Trust");
}

const pkg = JSON.parse(read("package.json"));
if (!pkg.scripts?.["validate:archive-state-delta"]) {
  fail("package.json missing validate:archive-state-delta");
}

try {
  const {
    captureArchiveStateSnapshot,
    buildArchiveStateDelta,
    buildDeltaRows,
  } = await import(path.join(ROOT, "packages/shared/lib/archive/archive-state-snapshot.ts"));

  const before = {
    belief: "I avoid conflict at work",
    confidence: 58,
    reputation: "moderate",
    evidenceCount: 8,
    lifeAreas: ["Work"],
    timestamp: new Date(Date.now() - 86400000 * 5).toISOString(),
  };

  const after = {
    belief: "I avoid conflict at work",
    confidence: 74,
    reputation: "high",
    evidenceCount: 21,
    lifeAreas: ["Work", "Relationships"],
    timestamp: new Date().toISOString(),
  };

  const rows = buildDeltaRows(before, after);
  if (rows.length < 3) fail("buildDeltaRows should surface confidence, evidence, life areas");
  const confidenceRow = rows.find((r) => r.kind === "confidence");
  if (!confidenceRow?.difference.includes("58% → 74%")) {
    fail("confidence delta must read 58% → 74%");
  }
  const evidenceRow = rows.find((r) => r.kind === "evidence");
  if (!evidenceRow?.difference.includes("8 → 21")) {
    fail("evidence delta must read 8 → 21");
  }
  const lifeRow = rows.find((r) => r.kind === "life_areas");
  if (!lifeRow?.difference.includes("Relationships")) {
    fail("life areas delta must mention new area");
  }
} catch (e) {
  fail(`archive-state-snapshot import test failed: ${e.message}`);
}

if (failures.length) {
  console.error("validate-archive-state-delta failed:\n");
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log("validate-archive-state-delta ok");
