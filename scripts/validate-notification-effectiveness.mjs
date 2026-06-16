#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const storage = new Map();
globalThis.window = globalThis;
globalThis.window.location = { pathname: "/internal/theory-discovery" };
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

function fail(msg) {
  failures.push(msg);
}

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
} = await import("../lib/theories/theory-notification-storage.ts");
const {
  clearDiscoverVisitForEval,
  saveDiscoverVisitBaseline,
} = await import("../lib/discover/discover-visit.ts");
const { buildTheoryTrackerReport } = await import("../lib/theories/theory-generation.ts");
const { clearTheorySnapshotsForEval } = await import("../lib/theories/theory-snapshots.ts");
const {
  NOTIFICATION_LIFECYCLE_EVENTS,
  readNotificationLifecycleEvents,
  readNotificationLifecycleRecords,
  recordNotificationOpened,
  recordNotificationsSeen,
  recordNotificationDismissed,
  syncExpiredNotifications,
  clearNotificationLifecycleForEval,
} = await import("../lib/theories/theory-notification-lifecycle.ts");
const { buildNotificationEffectivenessReport } = await import(
  "../lib/theories/notification-effectiveness.ts"
);
const { appendTheoryEventForEval, clearTheoryEventsForEval, THEORY_EVENTS } =
  await import("../lib/theories/theory-events.ts");
const { trackRetentionEvent, RETENTION_EVENTS, clearLocalEvents } = await import(
  "../lib/local-analytics.ts"
);
const { saveTheoryFeedback, clearTheoryFeedbackForEval } = await import(
  "../lib/theories/theory-feedback.ts"
);

clearDiscoverVisitForEval();
clearTheorySnapshotsForEval();
clearTheoryNotificationsForEval();
clearNotificationLifecycleForEval();
clearTheoryEventsForEval();
clearLocalEvents();
clearTheoryFeedbackForEval();

const report = buildTheoryTrackerReport(entries, { persistSnapshots: true });
const theory = report.all[0];
assert.ok(theory, "need theory fixture");

const baselineTheories = report.all.map((t) =>
  t.id === theory.id ? { ...t, confidence: Math.max(0, t.confidence - 8) } : t,
);
saveDiscoverVisitBaseline(baselineTheories, entries);

const gen = generateTheoryNotifications(entries, { persist: true });
assert.ok(gen.created.length >= 1, "expected notifications");

const eventsAfterCreate = readNotificationLifecycleEvents();
assert.ok(
  eventsAfterCreate.some((e) => e.name === NOTIFICATION_LIFECYCLE_EVENTS.created),
  "notification_created event missing",
);

const notification = readTheoryNotifications()[0];
assert.ok(notification, "notification in storage");

recordNotificationsSeen([notification]);
assert.ok(
  readNotificationLifecycleEvents().some((e) => e.name === NOTIFICATION_LIFECYCLE_EVENTS.seen),
  "notification_seen missing",
);

const openedAt = new Date().toISOString();
recordNotificationOpened(notification);
markTheoryNotificationRead(notification.id);

assert.ok(
  readNotificationLifecycleRecords().find((r) => r.notificationId === notification.id)?.openedAt,
  "openedAt on lifecycle record",
);

trackRetentionEvent(RETENTION_EVENTS.entryRecorded, { entryId: "e7" });
appendTheoryEventForEval(THEORY_EVENTS.discoverOpened, { theoryId: theory.id });
saveTheoryFeedback({
  theoryId: theory.id,
  reaction: "surprising",
  statement: theory.statement,
  source: theory.source,
  confidence: theory.confidence,
});

const effectiveness = buildNotificationEffectivenessReport();
assert.equal(effectiveness.totalNotifications, 1);
assert.ok(effectiveness.openRate === 100, `openRate ${effectiveness.openRate}`);
assert.ok(
  effectiveness.notificationReturnRate === 100,
  `return rate ${effectiveness.notificationReturnRate}`,
);
assert.ok(
  effectiveness.notificationToInsightRate === 100,
  `insight rate ${effectiveness.notificationToInsightRate}`,
);
assert.ok(effectiveness.winningByOpenRate.length >= 1);
assert.ok(effectiveness.bestCopy.length >= 1);
assert.equal(effectiveness.winningReportTitle, "What actually brings users back?");

// Dismiss path
clearTheoryNotificationsForEval();
clearNotificationLifecycleForEval();
saveDiscoverVisitBaseline(
  report.all.map((t) => ({ ...t, confidence: Math.max(0, t.confidence - 6) })),
  entries,
);
const gen2 = generateTheoryNotifications(entries, { persist: true });
const n2 = readTheoryNotifications().find((n) => !n.readAt);
if (n2) {
  recordNotificationDismissed(n2);
  assert.ok(
    readNotificationLifecycleEvents().some((e) => e.name === NOTIFICATION_LIFECYCLE_EVENTS.dismissed),
  );
}

// Expired + dead detection
clearNotificationLifecycleForEval();
const oldCreated = new Date(Date.now() - 15 * 24 * 60 * 60 * 1000).toISOString();
const oldRecord = {
  notificationId: "old-1",
  theoryId: theory.id,
  type: "weakened",
  title: "Old title",
  body: "Old body",
  createdAt: oldCreated,
};
storage.set(
  "voicememory_theory_notification_lifecycle",
  JSON.stringify([oldRecord]),
);
const expiredCount = syncExpiredNotifications();
assert.equal(expiredCount, 1);
assert.ok(
  readNotificationLifecycleEvents().some((e) => e.name === NOTIFICATION_LIFECYCLE_EVENTS.expired),
);

const withDead = buildNotificationEffectivenessReport();
const unopened14 = withDead.deadNotifications.find((f) => f.reason === "unopened_14d");
assert.ok(unopened14, "expected unopened_14d dead flag");

// Low open rate type flag (synthetic records)
clearNotificationLifecycleForEval();
const lowOpenRows = Array.from({ length: 5 }, (_, i) => ({
  notificationId: `low-${i}`,
  theoryId: theory.id,
  type: "retired",
  title: `T${i}`,
  body: "b",
  createdAt: new Date().toISOString(),
  dismissedAt: new Date().toISOString(),
}));
storage.set(
  "voicememory_theory_notification_lifecycle",
  JSON.stringify(lowOpenRows),
);
const lowReport = buildNotificationEffectivenessReport();
assert.ok(
  lowReport.deadNotifications.some((f) => f.reason === "low_open_rate_type"),
  "low open rate type flag",
);

// Dashboard wiring
const panelPath = path.join(ROOT, "components/internal/NotificationEffectivenessPanel.tsx");
const theoryPanelPath = path.join(ROOT, "components/internal/TheoryDiscoveryPanel.tsx");
if (!fs.existsSync(panelPath)) {
  fail("NotificationEffectivenessPanel missing");
}
const theoryPanelSrc = fs.readFileSync(theoryPanelPath, "utf8");
if (!theoryPanelSrc.includes("NotificationEffectivenessPanel")) {
  fail("TheoryDiscoveryPanel must render NotificationEffectivenessPanel");
}
const panelSrc = fs.readFileSync(panelPath, "utf8");
for (const needle of [
  "open rate",
  "return rate",
  "Potential dead notification",
  "winningReportTitle",
]) {
  if (!panelSrc.toLowerCase().includes(needle.toLowerCase())) {
    fail(`panel missing copy: ${needle}`);
  }
}

if (!fs.existsSync(path.join(ROOT, "lib/theories/notification-effectiveness.ts"))) {
  fail("notification-effectiveness.ts missing");
}

if (failures.length > 0) {
  console.error("validate-notification-effectiveness failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-notification-effectiveness ok");
