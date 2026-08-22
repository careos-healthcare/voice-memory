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
  "packages/shared/types/immediate-engagement.ts",
  "packages/shared/lib/archive/immediate-engagement.ts",
  "packages/shared/lib/archive/immediate-engagement-copy.ts",
  "packages/shared/lib/archive/archive-followup-storage.ts",
  "packages/shared/lib/metrics/immediate-engagement-events.ts",
  "apps/web/components/archive/ImmediateEngagementPanel.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const copy = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/archive/immediate-engagement-copy.ts"),
  "utf8",
);
if (!copy.includes("What ArchiveMe noticed")) fail("heading missing");
for (const kind of [
  "repeated_phrase",
  "possible_pattern",
  "theory_movement",
  "confidence_change",
  "contradiction",
  "new_evidence",
]) {
  if (!copy.includes(kind)) fail(`copy missing kind ${kind}`);
}
if (!copy.includes("IMMEDIATE_ENGAGEMENT_FORBIDDEN")) fail("forbidden regex missing");

const panel = fs.readFileSync(
  path.join(ROOT, "apps/web/components/archive/ImmediateEngagementPanel.tsx"),
  "utf8",
);
if (!panel.includes("trackFollowupShown")) fail("panel must track followup_shown");
if (!panel.includes("trackFollowupAnswered")) fail("panel must track followup_answered");
if (!panel.includes("persistArchiveFollowupAnswer")) fail("panel must persist answer");
if (!panel.includes('data-testid="immediate-engagement-panel"')) fail("panel test id missing");

const storage = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/archive/archive-followup-storage.ts"),
  "utf8",
);
if (!storage.includes("voicememory_archive_followup_answer")) {
  fail("archive_followup_answer storage key missing");
}

const events = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/metrics/immediate-engagement-events.ts"),
  "utf8",
);
for (const name of ["followup_shown", "followup_answered"]) {
  if (!events.includes(name)) fail(`event missing: ${name}`);
}

const engine = fs.readFileSync(path.join(ROOT, "packages/shared/lib/archive/immediate-engagement.ts"), "utf8");
if (engine.includes("mini-wow-internal")) fail("must not import mini-wow-internal");
const pickOrder = [
  "repeatedPhraseNotice",
  "possiblePatternNotice",
  "theoryMovementNotice",
  "confidenceChangeNotice",
  "contradictionNotice",
  "newEvidenceNotice",
];
let lastIdx = -1;
for (const fn of pickOrder) {
  const idx = engine.indexOf(fn);
  if (idx < 0) fail(`pickNotice missing ${fn}`);
  if (idx < lastIdx) fail(`pickNotice priority wrong near ${fn}`);
  lastIdx = idx;
}

const recorder = fs.readFileSync(path.join(ROOT, "apps/web/components/Recorder.tsx"), "utf8");
if (!recorder.includes("ImmediateEngagementPanel")) fail("Recorder must use ImmediateEngagementPanel");
if (!recorder.includes("buildImmediateEngagement")) fail("Recorder must build engagement");

const entryPage = fs.readFileSync(path.join(ROOT, "apps/web/app/entry/[id]/page.tsx"), "utf8");
if (!entryPage.includes("ImmediateEngagementPanel")) fail("entry page must use panel");

const pkg = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");
if (!pkg.includes("validate:immediate-engagement")) fail("package.json missing script");

const followupBlock = copy.slice(
  copy.indexOf("IMMEDIATE_FOLLOWUP_BY_KIND"),
  copy.indexOf("IMMEDIATE_ENGAGEMENT_FORBIDDEN"),
);
const forbidden = /\b(therapy|therapist|counsel|coach|CBT|cognitive behavioral|wellness|self-care|you should|try to|breathe|meditat|diagnos|disorder)\b/i;
for (const line of followupBlock.split("\n")) {
  if (line.includes(":") && forbidden.test(line)) {
    fail(`forbidden language in follow-up: ${line.trim()}`);
  }
}
if (forbidden.test(copy.match(/IMMEDIATE_ENGAGEMENT_HEADING[\s\S]*?;/m)?.[0] ?? "")) {
  fail("forbidden language in heading block");
}

const ls = new Map();
globalThis.window = { location: { pathname: "/validate-immediate-engagement" } };
globalThis.localStorage = {
  getItem: (k) => ls.get(String(k)) ?? null,
  setItem: (k, v) => ls.set(String(k), String(v)),
  removeItem: (k) => ls.delete(String(k)),
};

const { clearArchiveFollowupAnswersForEval, persistArchiveFollowupAnswer } = await import(
  "../packages/shared/lib/archive/archive-followup-storage.ts"
);
const {
  clearImmediateEngagementEventsForEval,
  countImmediateEngagementEvents,
  trackFollowupShown,
} = await import("../packages/shared/lib/metrics/immediate-engagement-events.ts");
const { buildImmediateEngagement } = await import("../packages/shared/lib/archive/immediate-engagement.ts");

clearArchiveFollowupAnswersForEval();
clearImmediateEngagementEventsForEval();

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
  "ie-1",
  "I keep saying I am failing when feedback arrives at work.",
  "2026-01-01T10:00:00.000Z",
);
const e2 = entry(
  "ie-2",
  "Same loop again — criticism means I am not good enough.",
  "2026-01-02T10:00:00.000Z",
);

const payload = buildImmediateEngagement([e1, e2], { newEntryId: "ie-2" });
assert.ok(payload.noticeDetail.length > 0);
assert.ok(payload.followUpQuestion.length > 0);
assert.equal(payload.noticeCategory.length > 0, true);

trackFollowupShown({
  followUpId: payload.followUpId,
  entryId: payload.entryId,
  noticeKind: payload.noticeKind,
});
persistArchiveFollowupAnswer({
  followUpId: payload.followUpId,
  entryId: payload.entryId,
  noticeKind: payload.noticeKind,
  answer: "yes",
});

assert.ok(ls.has("voicememory_archive_followup_answer"));
assert.equal(countImmediateEngagementEvents("followup_shown"), 1);

if (failures.length > 0) {
  console.error("validate-immediate-engagement failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-immediate-engagement ok", {
  noticeKind: payload.noticeKind,
  category: payload.noticeCategory,
});
