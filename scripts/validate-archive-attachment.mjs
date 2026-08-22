#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];
const fail = (msg) => failures.push(msg);

const required = [
  "packages/shared/types/archive-attachment.ts",
  "packages/shared/lib/archive/archive-attachment-copy.ts",
  "packages/shared/lib/archive/archive-attachment.ts",
  "packages/shared/lib/metrics/archive-attachment-events.ts",
  "packages/shared/lib/internal/archive-attachment-report.ts",
  "apps/web/components/archive/ArchiveAttachmentPrompt.tsx",
  "apps/web/components/internal/ArchiveAttachmentPanel.tsx",
  "apps/web/app/internal/archive-attachment/page.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const copy = fs.readFileSync(path.join(ROOT, "packages/shared/lib/archive/archive-attachment-copy.ts"), "utf8");
for (const phrase of [
  "If your archive disappeared tomorrow",
  "Not at all",
  "Extremely",
  "What would you miss most",
  "Belief history",
  "ARCHIVE_ATTACHMENT_MIN_REFLECTIONS = 5",
  "ARCHIVE_ATTACHMENT_COOLDOWN_MS = 14",
]) {
  if (!copy.includes(phrase) && !fs.readFileSync(path.join(ROOT, "packages/shared/lib/archive/archive-attachment.ts"), "utf8").includes(phrase)) {
    fail(`missing phrase/threshold: ${phrase}`);
  }
}

const events = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/metrics/archive-attachment-events.ts"),
  "utf8",
);
for (const name of [
  "archive_attachment_level",
  "archive_attachment_reason",
  "archive_moat_perception",
]) {
  if (!events.includes(name)) fail(`event missing: ${name}`);
}

const prompt = fs.readFileSync(
  path.join(ROOT, "apps/web/components/archive/ArchiveAttachmentPrompt.tsx"),
  "utf8",
);
if (!prompt.includes("saveArchiveAttachmentLevel")) fail("prompt must save level");
if (!prompt.includes('data-testid="archive-attachment-prompt"')) fail("level test id");

const report = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/internal/archive-attachment-report.ts"),
  "utf8",
);
if (!report.includes("Do users feel they own something valuable?")) fail("critical question");
if (!report.includes("ARCHIVE_ATTACHMENT_STRONG_THRESHOLD_PERCENT")) fail("strong threshold");

const attachmentWiring =
  fs.readFileSync(path.join(ROOT, "apps/web/components/archive/EvidenceArchiveHome.tsx"), "utf8");
if (!attachmentWiring.includes("ArchiveAttachmentPrompt")) {
  fail("EvidenceArchiveHome must wire ArchiveAttachmentPrompt");
}
if (!prompt.includes("archive-moat-perception-prompt")) {
  fail("ArchiveAttachmentPrompt must support moat perception");
}

const pkg = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");
if (!pkg.includes("validate:archive-attachment")) fail("package.json missing script");

const storage = new Map();
globalThis.window = { location: { pathname: "/validate-archive-attachment" } };
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

const { clearArchiveAttachmentForEval, canShowArchiveAttachmentPrompt, saveArchiveAttachmentLevel, saveArchiveAttachmentReason, shouldShowArchiveAttachmentReasonPrompt, ARCHIVE_ATTACHMENT_MIN_REFLECTIONS } = await import("../packages/shared/lib/archive/archive-attachment.ts");
const { clearArchiveAttachmentEventsForEval } = await import("../packages/shared/lib/metrics/archive-attachment-events.ts");
const { buildArchiveAttachmentReport } = await import("../packages/shared/lib/internal/archive-attachment-report.ts");

clearArchiveAttachmentForEval();
clearArchiveAttachmentEventsForEval();

assert.equal(ARCHIVE_ATTACHMENT_MIN_REFLECTIONS, 5);

const sparse = [
  {
    id: "a1",
    createdAt: "2026-01-01T12:00:00.000Z",
    transcript: "one",
    reflectionPending: false,
    reflection: { mood: "calm", hiddenConcern: "", recurringThemes: [] },
  },
];
assert.equal(canShowArchiveAttachmentPrompt(Date.now(), sparse), false);

const entries = [];
for (let i = 0; i < 6; i += 1) {
  entries.push({
    id: `e${i}`,
    createdAt: `2026-0${1 + Math.floor(i / 3)}-${String((i % 28) + 1).padStart(2, "0")}T12:00:00.000Z`,
    transcript: `reflection ${i} about work patterns`,
    reflectionPending: false,
    reflection: {
      mood: "reflective",
      hiddenConcern: "",
      recurringThemes: ["work"],
      emotionalIntensity: 3,
      positiveSignal: "",
      recommendation: "",
      concreteObservation: "note",
      repeatedSignal: "work",
    },
  });
}

assert.ok(canShowArchiveAttachmentPrompt(Date.now(), entries));

const record = saveArchiveAttachmentLevel("extremely", entries);
assert.equal(record.level, "extremely");
assert.equal(record.score, 4);

const ctx = shouldShowArchiveAttachmentReasonPrompt();
assert.ok(ctx);
saveArchiveAttachmentReason("belief_history", ctx);

const built = buildArchiveAttachmentReport();
assert.equal(built.totalResponses, 1);
assert.equal(built.strongAttachmentPercent, 100);
assert.equal(built.averageAttachmentScore, 4);
assert.ok(built.topAttachmentReasons[0]?.reason === "belief_history");

if (failures.length) {
  console.error("validate-archive-attachment failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-archive-attachment ok", { verdict: built.verdict, answer: built.criticalAnswer.slice(0, 64) });
