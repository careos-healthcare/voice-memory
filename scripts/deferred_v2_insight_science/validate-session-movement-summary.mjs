#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const failures = [];
const fail = (msg) => failures.push(msg);

const required = [
  "packages/shared/types/session-movement-summary.ts",
  "packages/shared/lib/archive/session-movement-summary.ts",
  "packages/shared/lib/archive/session-movement-summary-copy.ts",
  "packages/shared/lib/metrics/session-movement-summary-events.ts",
  "apps/web/components/archive/SessionMovementSummary.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const copy = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/archive/session-movement-summary-copy.ts"),
  "utf8",
);
for (const phrase of [
  "What changed",
  "Your archive added new evidence",
  "Confidence moved",
  "A contradiction appeared",
  "comparison point",
]) {
  if (!copy.includes(phrase)) fail(`copy missing: ${phrase}`);
}
if (copy.includes("reflection saved")) fail("must not lead with reflection saved");

const panel = fs.readFileSync(
  path.join(ROOT, "apps/web/components/archive/SessionMovementSummary.tsx"),
  "utf8",
);
if (!panel.includes("trackSessionMovementSummarySeen")) fail("must track seen");
if (!panel.includes("trackSessionMovementSummaryExpanded")) fail("must track expanded");
if (!panel.includes('data-testid="session-movement-summary"')) fail("test id missing");

const events = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/metrics/session-movement-summary-events.ts"),
  "utf8",
);
for (const name of ["session_movement_summary_seen", "session_movement_summary_expanded"]) {
  if (!events.includes(name)) fail(`event missing: ${name}`);
}

for (const rel of [
  "apps/web/components/Recorder.tsx",
  "apps/web/app/discover/page.tsx",
  "apps/web/app/memory/page.tsx",
  "apps/web/app/blind-spots/page.tsx",
]) {
  const src = fs.readFileSync(path.join(ROOT, rel), "utf8");
  if (!src.includes("SessionMovementSummary")) fail(`${rel} must wire SessionMovementSummary`);
}

const storage = new Map();
globalThis.window = { location: { pathname: "/validate-session-movement-summary" } };
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

const { buildSessionMovementSummary } = await import(
  "../../packages/shared/lib/archive/session-movement-summary.ts"
);

function entry(id, transcript, createdAt) {
  return {
    id,
    createdAt,
    transcript,
    durationSeconds: 45,
    reflectionPending: false,
    reflection: {
      mood: "reflective",
      emotionalIntensity: 3,
      recurringThemes: ["work", "relationships"],
      hiddenConcern: "",
      positiveSignal: "",
      recommendation: "",
      concreteObservation: transcript.slice(0, 80),
      repeatedSignal: "criticism",
    },
  };
}

const summary = buildSessionMovementSummary(
  [
    entry("e1", "I keep saying I need to prove myself at work.", "2026-01-01T12:00:00.000Z"),
    entry(
      "e2",
      "Manager feedback still spirals when I hear criticism.",
      "2026-01-15T12:00:00.000Z",
    ),
  ],
  { newEntryId: "e2" },
);
assert.ok(summary?.headline, "summary headline required");

if (failures.length) {
  console.error("validate-session-movement-summary failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-session-movement-summary ok", { kind: summary?.kind });
