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
  "packages/shared/types/archive-belief.ts",
  "packages/shared/lib/archive/archive-belief.ts",
  "packages/shared/lib/archive/archive-belief-copy.ts",
  "packages/shared/lib/metrics/archive-belief-events.ts",
  "packages/shared/lib/metrics/archive-belief-adoption-report.ts",
  "apps/web/components/archive/ArchiveBeliefCard.tsx",
  "apps/web/components/archive/ArchiveBeliefEvidenceSection.tsx",
  "apps/web/components/archive/CurrentArchiveBeliefStrip.tsx",
  "apps/web/components/archive/HomeArchiveBeliefIntro.tsx",
  "apps/web/components/internal/ArchiveBeliefAdoptionPanel.tsx",
  "apps/web/app/internal/archive-belief/page.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const copy = fs.readFileSync(path.join(ROOT, "packages/shared/lib/archive/archive-belief-copy.ts"), "utf8");
for (const phrase of [
  "What your archive currently believes",
  "Your archive currently believes:",
  "What changed",
  "Why the archive believes this",
  "Under review",
  "Strengthening",
  "Recent reflections support this theory",
  "Archive beliefs",
  "Your archive is building a view of you",
]) {
  if (!copy.includes(phrase)) fail(`copy missing: ${phrase}`);
}

const card = fs.readFileSync(path.join(ROOT, "apps/web/components/archive/ArchiveBeliefCard.tsx"), "utf8");
for (const fn of [
  "trackArchiveBeliefViewed",
  "trackArchiveBeliefExpanded",
  "trackBeliefChangeViewed",
]) {
  if (!card.includes(fn)) fail(`ArchiveBeliefCard missing ${fn}`);
}
if (!card.includes('data-testid="archive-belief-card"')) fail("belief card test id");

const events = fs.readFileSync(path.join(ROOT, "packages/shared/lib/metrics/archive-belief-events.ts"), "utf8");
for (const name of [
  "archive_belief_viewed",
  "archive_belief_expanded",
  "belief_change_viewed",
]) {
  if (!events.includes(name)) fail(`event missing: ${name}`);
}

const discover = fs.readFileSync(path.join(ROOT, "apps/web/app/discover/page.tsx"), "utf8");
if (!discover.includes("ArchiveBeliefCard")) fail("discover must show ArchiveBeliefCard");
if (!discover.includes("TheoryChangeFeed")) fail("discover must show TheoryChangeFeed");
if (!discover.includes("ArchiveProductWayfinding")) {
  fail("discover must link back to archive-belief");
}

const memory = fs.readFileSync(path.join(ROOT, "apps/web/app/memory/page.tsx"), "utf8");
if (!memory.includes("CurrentArchiveBeliefStrip")) fail("memory must show current belief");

const home = fs.readFileSync(path.join(ROOT, "apps/web/app/page.tsx"), "utf8");
if (!home.includes("HomeArchiveBeliefIntro")) fail("home must use HomeArchiveBeliefIntro");
if (home.includes("ArchiveValueBanner")) fail("home should replace ArchiveValueBanner framing");

const { THEORY_PAGE } = await import("../packages/shared/lib/theories/theory-copy.ts");
if (THEORY_PAGE.title !== "Archive beliefs") {
  fail(`theories title must be Archive beliefs, got ${THEORY_PAGE.title}`);
}
if (THEORY_PAGE.eyebrow !== "Archive beliefs") {
  fail(`theories eyebrow must be Archive beliefs, got ${THEORY_PAGE.eyebrow}`);
}

const pkg = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");
if (!pkg.includes("validate:archive-belief-system")) fail("package.json missing script");

const storage = new Map();
globalThis.window = { location: { pathname: "/validate-archive-belief" } };
globalThis.localStorage = {
  getItem: (k) => storage.get(String(k)) ?? null,
  setItem: (k, v) => storage.set(String(k), String(v)),
  removeItem: (k) => storage.delete(String(k)),
  clear: () => storage.clear(),
  get length() {
    return storage.size;
  },
  key: (i) => [...storage.keys()][i] ?? null,
};

const { clearArchiveBeliefEventsForEval, trackArchiveBeliefViewed, countArchiveBeliefEvent } =
  await import("../packages/shared/lib/metrics/archive-belief-events.ts");
const { buildArchiveBeliefView } = await import("../packages/shared/lib/archive/archive-belief.ts");
const { buildArchiveBeliefAdoptionReport } = await import(
  "../packages/shared/lib/metrics/archive-belief-adoption-report.ts"
);
const { scanArchiveVoiceSource } = await import("../packages/shared/lib/archive/archive-voice.ts");

clearArchiveBeliefEventsForEval();

function entry(id, transcript, createdAt) {
  return {
    id,
    createdAt,
    transcript,
    durationSeconds: 45,
    reflection: {
      mood: "reflective",
      emotionalIntensity: 3,
      recurringThemes: ["work", "relationships"],
      hiddenConcern: "",
      positiveSignal: "",
      recommendation: "",
      concreteObservation: transcript.slice(0, 80),
      repeatedSignal: "rejection at work",
    },
  };
}

const entries = [
  entry(
    "ab-1",
    "My manager criticized me and I felt rejected at work again.",
    "2026-01-01T10:00:00.000Z",
  ),
  entry(
    "ab-2",
    "Partner said I shut down — same rejection feeling at home.",
    "2026-01-08T10:00:00.000Z",
  ),
  entry(
    "ab-3",
    "Criticism at work still lands as proof I am not enough.",
    "2026-01-15T10:00:00.000Z",
  ),
];

const view = buildArchiveBeliefView(entries);
assert.ok(view, "belief view should exist with 3 entries");
assert.ok(view.belief.length > 10);
assert.ok(view.statusLabel.length > 0);
assert.ok(view.changeLines.length >= 0);
assert.ok(view.evidence.supportingQuotes.length >= 0);

trackArchiveBeliefViewed({ theoryId: view.theoryId, surface: "discover" });
assert.equal(countArchiveBeliefEvent("archive_belief_viewed"), 1);

const adoption = buildArchiveBeliefAdoptionReport();
assert.equal(adoption.title, "Archive Belief Adoption");

const voiceHits = scanArchiveVoiceSource(copy, "archive-belief-copy.ts");
if (voiceHits.length > 0) {
  fail(`archive belief copy failed voice check: ${voiceHits[0].match}`);
}

if (failures.length > 0) {
  console.error("validate-archive-belief-system failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-archive-belief-system ok", {
  belief: view.belief.slice(0, 48),
  status: view.statusLabel,
  changes: view.changeLines.length,
});
