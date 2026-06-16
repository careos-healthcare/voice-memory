#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const storage = new Map();
globalThis.window = globalThis;
globalThis.window.location = { pathname: "/internal/test" };
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

function entry(id, day, transcript) {
  const month = day > 28 ? "02" : "01";
  const dayInMonth = day > 28 ? day - 28 : day;
  const date = new Date(
    `2026-${month}-${String(dayInMonth).padStart(2, "0")}T12:00:00.000Z`,
  );
  return {
    id,
    createdAt: date.toISOString(),
    transcript,
    reflection: {
      mood: "tense",
      emotionalIntensity: 6,
      recurringThemes: ["work"],
      hiddenConcern: "",
      positiveSignal: "",
      recommendation: "",
    },
    durationSeconds: 40,
  };
}

const entries = [
  entry("e1", 1, "I keep saying I will start Monday but I never do."),
  entry("e2", 5, "I want to change but I keep doing the same thing at work."),
  entry("e3", 10, "I keep avoiding the conversation with my manager."),
  entry("e4", 15, "Maybe I will eventually tell them — I don't know."),
  entry("e5", 20, "I keep circling the same worry about money and work."),
  entry("e6", 28, "I should have spoken up but I keep waiting to quit."),
];

const {
  generateTheoryNotifications,
} = await import("../lib/theories/theory-notification-generator.ts");
const {
  clearTheoryNotificationsForEval,
  readTheoryNotifications,
  markTheoryNotificationRead,
  countUnreadTheoryNotifications,
  THEORY_NOTIFICATIONS_KEY,
} = await import("../lib/theories/theory-notification-storage.ts");
const {
  clearDiscoverVisitForEval,
  saveDiscoverVisitBaseline,
  readDiscoverBaseline,
} = await import("../lib/discover/discover-visit.ts");
const { buildTheoryTrackerReport } = await import("../lib/theories/theory-generation.ts");
const { clearTheorySnapshotsForEval } = await import("../lib/theories/theory-snapshots.ts");
const {
  FORBIDDEN_NOTIFICATION_COPY,
  sanitizeNotificationCopy,
  copyForNotification,
} = await import("../lib/theories/theory-notification-copy.ts");
const { DISCOVER_BASELINE_VERSION } = await import(
  "../lib/discover/theory-evidence-snapshot.ts"
);

clearDiscoverVisitForEval();
clearTheorySnapshotsForEval();
clearTheoryNotificationsForEval();

// No notification on first visit (no baseline)
const firstVisit = generateTheoryNotifications(entries, { persist: false });
assert.equal(firstVisit.skippedFirstVisit, true);
assert.equal(firstVisit.created.length, 0);

const report = buildTheoryTrackerReport(entries, { persistSnapshots: true });
assert.ok(report.all.length >= 1, "need theories from fixture");
const theory = report.all[0];

// Baseline with lower confidence
const baselineTheories = report.all.map((t) =>
  t.id === theory.id ? { ...t, confidence: Math.max(0, t.confidence - 8) } : t,
);
saveDiscoverVisitBaseline(baselineTheories, entries);

clearTheoryNotificationsForEval();
const confidenceRun = generateTheoryNotifications(entries, { persist: true });
assert.equal(confidenceRun.skippedFirstVisit, false);
assert.ok(
  confidenceRun.created.some((n) => n.type === "strengthened"),
  "expected strengthened notification for confidence delta >= 5",
);
const strengthened = confidenceRun.created.find((n) => n.type === "strengthened");
assert.ok(strengthened && Math.abs(strengthened.confidenceDelta ?? 0) >= 5);
assert.ok(strengthened.title.includes("strengthened"));

// Deduplication
const secondRun = generateTheoryNotifications(entries, { persist: true });
assert.equal(secondRun.created.length, 0, "dedupe should block repeat notifications");
assert.ok(readTheoryNotifications().length >= 1);

// Contradiction copy + dedupe key behavior
const contraCopy = copyForNotification({
  type: "contradiction",
  theory,
  evidenceSummary: "One new reflection may pull against this theory.",
});
assert.ok(
  contraCopy.body.includes("pull") || contraCopy.body.includes("contradict"),
  "contradiction copy should reference tension",
);
assert.ok(!FORBIDDEN_NOTIFICATION_COPY.test(contraCopy.body));

const baselineSnap = readDiscoverBaseline();
assert.ok(baselineSnap);
const target = baselineSnap.theories[0];
const patchedBaseline = {
  ...baselineSnap,
  theories: baselineSnap.theories.map((t, i) =>
    i === 0
      ? { ...t, contradictingEntryIds: [], supportingEntryIds: ["e1"] }
      : t,
  ),
};
storage.set("voicememory_discover_visit_baseline", JSON.stringify(patchedBaseline));
clearTheoryNotificationsForEval();
// Add a late entry so new supporting can qualify for new_evidence after 7+ days
const wideEntries = [
  ...entries,
  entry("e7", 40, "I want to leave my job but I also need to stay — tension at work."),
];
saveDiscoverVisitBaseline(
  buildTheoryTrackerReport(wideEntries, { persistSnapshots: false }).all.map((t) =>
    t.id === target.id ? { ...t, confidence: t.confidence } : t,
  ),
  wideEntries,
);
storage.set(
  "voicememory_discover_visit_baseline",
  JSON.stringify({
    ...patchedBaseline,
    savedAt: entries[0].createdAt,
  }),
);
clearTheoryNotificationsForEval();
const wideRun = generateTheoryNotifications(wideEntries, { persist: true });
assert.ok(
  wideRun.created.length >= 1 || readTheoryNotifications().length >= 1,
  "expected at least one notification after baseline with gap entries",
);

// Resolved / retired copy
const retiredCopy = copyForNotification({
  type: "retired",
  theory,
  evidenceSummary: "May no longer fit.",
});
assert.ok(retiredCopy.title.includes("may no longer fit"));
assert.equal(retiredCopy.relatedRoute, "/theories");
const resolvedCopy = copyForNotification({
  type: "resolved",
  theory,
  evidenceSummary: "Your archive suggests this may be settling.",
});
assert.ok(resolvedCopy.title.includes("may no longer fit"));

// Mark read
clearTheoryNotificationsForEval();
generateTheoryNotifications(entries, { persist: true });
const all = readTheoryNotifications();
assert.ok(all.length >= 1);
assert.ok(countUnreadTheoryNotifications() >= 1);
const marked = markTheoryNotificationRead(all[0].id);
assert.ok(marked?.readAt);
assert.equal(countUnreadTheoryNotifications(), all.length - 1);

// Forbidden copy guard
const toxic = sanitizeNotificationCopy("You have a clinical disorder and need therapy now.");
assert.ok(!FORBIDDEN_NOTIFICATION_COPY.test(toxic));
const sample = copyForNotification({
  type: "strengthened",
  theory,
  evidenceSummary: "Confidence may have risen.",
  confidenceDelta: 8,
});
assert.ok(!FORBIDDEN_NOTIFICATION_COPY.test(sample.body));
assert.ok(/\bmay\b/i.test(sample.body) || /\bsuggest/i.test(sample.body));

const required = [
  "types/theory-notification.ts",
  "lib/theories/theory-notification-generator.ts",
  "lib/theories/theory-notification-storage.ts",
  "lib/theories/theory-notification-copy.ts",
  "components/theories/TheoryUpdatesNav.tsx",
  "components/theories/TheoryNotificationCard.tsx",
  "app/updates/page.tsx",
  "components/discover/TheoryChangeFeed.tsx",
  "components/SiteHeader.tsx",
  "voicememory_theory_notifications",
];

for (const rel of required) {
  const full = path.join(ROOT, rel);
  if (rel.includes(".")) {
    if (!fs.existsSync(full)) failures.push(`missing ${rel}`);
  } else if (!fs.readFileSync(path.join(ROOT, "lib/theories/theory-notification-storage.ts"), "utf8").includes(rel)) {
    failures.push(`storage must use ${rel}`);
  }
}

const pageSrc = fs.readFileSync(path.join(ROOT, "app/updates/page.tsx"), "utf8");
if (!pageSrc.includes("markTheoryNotificationRead")) {
  failures.push("updates page must mark read on open");
}

const feedSrc = fs.readFileSync(
  path.join(ROOT, "components/discover/TheoryChangeFeed.tsx"),
  "utf8",
);
if (!feedSrc.includes("generateTheoryNotifications")) {
  failures.push("discover feed must generate notifications");
}
if (!feedSrc.includes("hasBaseline")) {
  failures.push("discover must skip first visit");
}

const pkg = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");
if (!pkg.includes("validate:theory-notifications")) {
  failures.push("package.json missing validate:theory-notifications");
}

if (failures.length > 0) {
  console.error("validate-theory-notifications failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-theory-notifications ok");
