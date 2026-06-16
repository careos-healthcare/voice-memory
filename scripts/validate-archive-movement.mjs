#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

function fail(msg) {
  failures.push(msg);
}

const required = [
  "types/archive-movement.ts",
  "lib/archive/archive-movement.ts",
  "lib/archive/archive-movement-copy.ts",
  "lib/metrics/archive-movement-events.ts",
  "components/archive/ArchiveMovementCard.tsx",
  "components/archive/LatestArchiveMovementCard.tsx",
  "apps/voicememory_mobile/lib/features/archive_movement/archive_movement.dart",
  "apps/voicememory_mobile/lib/widgets/archive_movement_card.dart",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const copy = fs.readFileSync(path.join(ROOT, "lib/archive/archive-movement-copy.ts"), "utf8");
const emotional = fs.readFileSync(
  path.join(ROOT, "lib/archive/archive-emotional-copy.ts"),
  "utf8",
);
for (const phrase of [
  "Archive update",
  "The archive has become more certain.",
  "New experiences supported this view.",
  "evidenceHarderToFool",
  "Possible contradiction detected",
  "still evaluating this theory",
]) {
  if (!copy.includes(phrase) && !emotional.includes(phrase)) fail(`copy missing: ${phrase}`);
}
if (!copy.includes("ARCHIVE_EMOTIONAL")) {
  fail("archive-movement-copy must use ARCHIVE_EMOTIONAL");
}

const card = fs.readFileSync(
  path.join(ROOT, "components/archive/ArchiveMovementCard.tsx"),
  "utf8",
);
if (!card.includes("trackArchiveUpdateSeen")) fail("card must track seen");
if (!card.includes("trackArchiveUpdateExpanded")) fail("card must track expanded");
if (!card.includes('data-testid="archive-movement-card"')) fail("card test id missing");

const events = fs.readFileSync(
  path.join(ROOT, "lib/metrics/archive-movement-events.ts"),
  "utf8",
);
if (!events.includes("voicememory_archive_updates")) fail("storage key missing");

const engine = fs.readFileSync(path.join(ROOT, "lib/archive/archive-movement.ts"), "utf8");
const priorities = [
  "confidence_changed",
  "evidence_increased",
  "status_changed",
  "new_life_area",
  "contradiction_detected",
  "cost_evidence_detected",
  "under_review",
];
for (const kind of priorities) {
  if (!engine.includes(`"${kind}"`)) fail(`engine missing kind ${kind}`);
}

const recorder = fs.readFileSync(path.join(ROOT, "components/Recorder.tsx"), "utf8");
if (!recorder.includes("ArchiveMovementCard")) fail("Recorder must use ArchiveMovementCard");
if (recorder.includes("ArchiveChangedMessage")) {
  fail("Recorder must not use ArchiveChangedMessage as primary");
}

const entryPage = fs.readFileSync(path.join(ROOT, "app/entry/[id]/page.tsx"), "utf8");
if (!entryPage.includes("ArchiveMovementCard")) fail("entry page must use ArchiveMovementCard");

const memoryPage = fs.readFileSync(path.join(ROOT, "app/memory/page.tsx"), "utf8");
if (!memoryPage.includes("LatestArchiveMovementCard")) fail("memory page must show movement");

const recordDart = fs.readFileSync(
  path.join(ROOT, "apps/voicememory_mobile/lib/screens/record_screen.dart"),
  "utf8",
);
if (!recordDart.includes("ArchiveMovementCard")) fail("mobile record must use ArchiveMovementCard");

const pkg = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");
if (!pkg.includes("validate:archive-movement")) fail("package.json missing script");

const storage = new Map();
globalThis.window = {
  location: { pathname: "/validate-archive-movement" },
};
globalThis.localStorage = {
  getItem: (k) => storage.get(String(k)) ?? null,
  setItem: (k, v) => storage.set(String(k), String(v)),
  removeItem: (k) => storage.delete(String(k)),
};

const { clearArchiveMovementForEval, persistArchiveMovement, countArchiveMovementEvents } =
  await import("../lib/metrics/archive-movement-events.ts");
const { buildArchiveMovementUpdate } = await import("../lib/archive/archive-movement.ts");

clearArchiveMovementForEval();

function entry(id, transcript, createdAt) {
  return {
    id,
    createdAt,
    transcript,
    durationSeconds: 45,
    reflection: {
      mood: "reflective",
      emotionalIntensity: 3,
      recurringThemes: ["work"],
      hiddenConcern: "",
      positiveSignal: "",
      recommendation: "",
      concreteObservation: transcript.slice(0, 80),
      repeatedSignal: "failure language",
    },
  };
}

const e1 = entry(
  "am-1",
  "I keep saying I am failing when feedback arrives at work.",
  "2026-01-01T10:00:00.000Z",
);
const e2 = entry(
  "am-2",
  "Same loop again — criticism means I am not good enough.",
  "2026-01-02T10:00:00.000Z",
);

const first = buildArchiveMovementUpdate([e1], { newEntryId: "am-1" });
assert.ok(first.headline.length > 0);
assert.notEqual(first.headline.toLowerCase(), "reflection saved");
persistArchiveMovement(first, { entryId: "am-1", reflectionCount: 1 });

const second = buildArchiveMovementUpdate([e1, e2], { newEntryId: "am-2" });
assert.ok(second.headline.length > 0);
assert.ok(storage.has("voicememory_archive_updates"));

if (failures.length > 0) {
  console.error("validate-archive-movement failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-archive-movement ok", {
  firstKind: first.kind,
  secondKind: second.kind,
  seen: countArchiveMovementEvents("archive_update_seen"),
});
