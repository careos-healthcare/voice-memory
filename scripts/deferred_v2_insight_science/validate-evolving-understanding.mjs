#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const failures = [];

function fail(msg) {
  failures.push(msg);
}

function read(rel) {
  return fs.readFileSync(path.join(ROOT, rel), "utf8");
}

const required = [
  "packages/shared/lib/product/evolving-understanding-copy.ts",
  "packages/shared/lib/metrics/evolving-understanding-events.ts",
  "packages/shared/lib/metrics/evolving-understanding-report.ts",
  "packages/shared/lib/metrics/evolving-understanding-return.ts",
  "packages/shared/lib/theories/evolving-view-snapshot.ts",
  "packages/shared/types/evolving-understanding.ts",
  "apps/web/components/blind-spots/WhatHappensNextPanel.tsx",
  "apps/web/components/theories/EvolvingViewCard.tsx",
  "apps/web/components/internal/EvolvingUnderstandingPanel.tsx",
];

for (const rel of required) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const blindCopy = read("packages/shared/lib/blind-spots/blind-spot-copy.ts");
for (const phrase of [
  "first theory your archive can support",
  "strengthen, weaken, or disappear",
  "evidence-based view of what keeps repeating",
  "First working theory",
]) {
  if (!blindCopy.includes(phrase)) fail(`blind spot copy missing: ${phrase}`);
}

const copy = read("packages/shared/lib/product/evolving-understanding-copy.ts");
if (!copy.includes("What happens next?")) fail("WhatHappensNext title missing");
if (!copy.includes('ctaHref: "/discover"')) fail("WhatHappensNext must link to /discover");
if (!copy.includes("Check what changes")) fail("WhatHappensNext CTA missing");

const whatNext = read("apps/web/components/blind-spots/WhatHappensNextPanel.tsx");
if (!whatNext.includes("WHAT_HAPPENS_NEXT")) fail("WhatHappensNextPanel must use copy");

const card = read("apps/web/components/theories/EvolvingViewCard.tsx");
const snapshot = read("packages/shared/lib/theories/evolving-view-snapshot.ts");
for (const phrase of [
  "started forming a view",
  "Each new reflection can change",
]) {
  if (!copy.includes(phrase)) fail(`evolving view copy missing: ${phrase}`);
}
for (const phrase of ["underReviewCount", "strengtheningCount", "weakeningOrResolvedCount"]) {
  if (!snapshot.includes(phrase)) fail(`evolving view snapshot missing: ${phrase}`);
}
if (!card.includes("EVOLVING_VIEW_CARD")) fail("EvolvingViewCard must use copy");

const events = read("packages/shared/lib/metrics/evolving-understanding-events.ts");
for (const name of [
  "voicememory_evolving_understanding_events",
  "first_working_theory_seen",
  "evolving_view_card_seen",
  "what_happens_next_clicked",
  "discover_after_first_blind_spot_opened",
  "returned_to_check_archive_view",
  "RETURN_TO_CHECK_ARCHIVE_HOURS = 24",
]) {
  if (!events.includes(name)) fail(`events missing: ${name}`);
}

const reportSrc = read("packages/shared/lib/metrics/evolving-understanding-report.ts");
for (const field of [
  "firstBlindSpotSeenCount",
  "evolvingViewCardSeenCount",
  "discoverAfterFirstBlindSpotRate",
  "returnedToCheckArchiveViewRate",
  "whatHappensNextClickRate",
  "archive view may have changed",
]) {
  if (!reportSrc.includes(field)) fail(`report missing: ${field}`);
}

const paywall = read("packages/shared/lib/billing/value-moment-paywall-copy.ts");
for (const phrase of [
  "Keep the evolving archive alive",
  "First working belief",
  "Full evidence timeline",
]) {
  if (!paywall.includes(phrase)) fail(`paywall copy missing: ${phrase}`);
}

const ladder = read("packages/shared/lib/theories/personal-theory-status.ts");
if (!ladder.includes("First working theory unlocked")) {
  fail("ladder missing first working theory unlocked");
}
if (!ladder.includes("One data point")) fail("ladder missing one data point");

const intro = read("packages/shared/lib/product-copy.ts");
if (!intro.includes("working view from repeated evidence")) {
  fail("onboarding intro missing working view");
}

const forbidden = [
  blindCopy,
  read("packages/shared/lib/product/evolving-understanding-copy.ts"),
  paywall,
].join("\n");
if (/\bdiagnos(e|is|ed)\b/i.test(forbidden) && !/not a diagnos/i.test(forbidden)) {
  fail("forbidden diagnosis language");
}
if (/\btherapy\b/i.test(forbidden) && !/not therapy/i.test(forbidden)) {
  fail("forbidden therapy promotion");
}
if (/\bverdict\b/i.test(forbidden) && !/not a verdict/i.test(forbidden)) {
  fail("certainty/verdict language without hedge");
}

const review = read("apps/web/components/blind-spots/BlindSpotReview.tsx");
if (!review.includes("WhatHappensNextPanel")) fail("BlindSpotReview must show WhatHappensNext");
if (!review.includes("recordFirstWorkingTheorySeen")) {
  fail("BlindSpotReview must record first working theory");
}

const pkg = read("package.json");
}

const storage = new Map();
globalThis.window = globalThis;
globalThis.localStorage = {
  getItem: (k) => storage.get(String(k)) ?? null,
  setItem: (k, v) => storage.set(String(k), String(v)),
  removeItem: (k) => storage.delete(String(k)),
};
storage.set(
  "voicememory_value_moment_paywall",
  JSON.stringify({ hasSeenFirstBlindSpot: true }),
);

const {
  clearEvolvingUnderstandingForEval,
  recordFirstWorkingTheorySeen,
  maybeTrackReturnedToCheckArchiveView,
  readEvolvingUnderstandingEvents,
  readEvolvingUnderstandingState,
  EVOLVING_UNDERSTANDING_EVENTS_KEY,
} = await import("../../packages/shared/lib/metrics/evolving-understanding-events.ts");

const { buildEvolvingUnderstandingReport } = await import(
  "../../packages/shared/lib/metrics/evolving-understanding-report.ts"
);

clearEvolvingUnderstandingForEval();
recordFirstWorkingTheorySeen();
assert.ok(readEvolvingUnderstandingEvents().some((e) => e.name === "first_working_theory_seen"));
assert.ok(storage.has(EVOLVING_UNDERSTANDING_EVENTS_KEY));

const state = readEvolvingUnderstandingState();
state.firstWorkingTheorySeenAt = new Date(Date.now() - 25 * 60 * 60 * 1000).toISOString();
storage.set("voicememory_evolving_understanding_state", JSON.stringify(state));
maybeTrackReturnedToCheckArchiveView("discover");
assert.ok(
  readEvolvingUnderstandingEvents().some((e) => e.name === "returned_to_check_archive_view"),
);

const metricsReport = buildEvolvingUnderstandingReport();
assert.equal(metricsReport.firstBlindSpotSeenCount, 1);
assert.ok(metricsReport.lines.length >= 3);

if (failures.length > 0) {
  console.error("validate-evolving-understanding failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-evolving-understanding ok");
