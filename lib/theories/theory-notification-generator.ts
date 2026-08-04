import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { readDiscoverBaseline } from "@/lib/discover/discover-visit";
import {
  buildDiscoverEvidenceContext,
  theoryToEvidenceBaseline,
} from "@/lib/discover/theory-evidence-snapshot";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import {
  appendTheoryNotifications,
  readTheoryNotifications,
} from "@/lib/theories/theory-notification-storage";
import { copyForNotification } from "@/lib/theories/theory-notification-copy";
import type { Theory, TheoryEvidenceBaselineEntry } from "@/types/theory";
import type {
  TheoryNotification,
  TheoryNotificationGenerationReport,
  TheoryNotificationType,
} from "@/types/theory-notification";
import type { JournalEntry } from "@/types/journal";

const CONFIDENCE_DELTA_MIN = 5;
const SUPPORTING_GAP_DAYS = 7;

function newId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `tn-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

function dedupeKey(
  theoryId: string,
  type: TheoryNotificationType,
  evidenceIds: string[],
): string {
  const ids = [...evidenceIds].sort().join(",");
  return `${theoryId}:${type}:${ids}`;
}

function baselineSets(prev: TheoryEvidenceBaselineEntry | undefined) {
  if (!prev) {
    return {
      supporting: new Set<string>(),
      contradicting: new Set<string>(),
      predictionKey: undefined as string | undefined,
    };
  }
  return {
    supporting: new Set(prev.supportingEntryIds),
    contradicting: new Set(prev.contradictingEntryIds),
    predictionKey: prev.predictionOutcomeKey,
  };
}

function entryDayKey(entryId: string, entriesById: Map<string, JournalEntry>): string | null {
  const entry = entriesById.get(entryId);
  return entry ? toDayKey(entry.createdAt) : null;
}

function latestDayKey(entryIds: string[], entriesById: Map<string, JournalEntry>): string | null {
  const keys = entryIds
    .map((id) => entryDayKey(id, entriesById))
    .filter((k): k is string => Boolean(k))
    .sort();
  return keys.length > 0 ? keys[keys.length - 1]! : null;
}

function newEntryIds(current: string[], baseline: Set<string>): string[] {
  return current.filter((id) => !baseline.has(id));
}

function buildNotification(
  theory: Theory,
  type: TheoryNotificationType,
  evidenceSummary: string,
  evidenceIds: string[],
  confidenceDelta?: number,
): TheoryNotification {
  const copy = copyForNotification({ type, theory, evidenceSummary, confidenceDelta });
  return {
    id: newId(),
    theoryId: theory.id,
    type,
    title: copy.title,
    body: copy.body,
    createdAt: new Date().toISOString(),
    importance: copy.importance,
    relatedRoute: copy.relatedRoute,
    evidenceSummary,
    confidenceDelta,
    dedupeKey: dedupeKey(theory.id, type, evidenceIds),
  };
}

function candidatesFromComparison(
  baseline: NonNullable<ReturnType<typeof readDiscoverBaseline>>,
  entries: JournalEntry[],
): TheoryNotification[] {
  const context = buildDiscoverEvidenceContext(entries);
  const entriesById = new Map(context.eligible.map((e) => [e.id, e]));
  const report = buildTheoryTrackerReport(entries, { persistSnapshots: false });
  const baselineById = new Map(baseline.theories.map((t) => [t.id, t]));
  const baselineSavedDay = toDayKey(baseline.savedAt);
  const created: TheoryNotification[] = [];
  const existingKeys = new Set(readTheoryNotifications().map((n) => n.dedupeKey));

  const push = (notification: TheoryNotification) => {
    if (existingKeys.has(notification.dedupeKey)) return;
    created.push(notification);
    existingKeys.add(notification.dedupeKey);
  };

  for (const theory of report.all) {
    const prev = baselineById.get(theory.id);
    const snapshot = theoryToEvidenceBaseline(theory, entries, context);
    const base = baselineSets(prev);
    const supportingIds = theory.supportingEvidence.map((q) => q.entryId);
    const contradictingIds = theory.contradictingEvidence.map((q) => q.entryId);

    if (prev) {
      const delta = theory.confidence - prev.confidence;
      if (delta >= CONFIDENCE_DELTA_MIN) {
        push(
          buildNotification(
            theory,
            "strengthened",
            `Confidence may have risen from ${prev.confidence} to ${theory.confidence}.`,
            supportingIds,
            delta,
          ),
        );
      } else if (delta <= -CONFIDENCE_DELTA_MIN) {
        push(
          buildNotification(
            theory,
            "weakened",
            `Confidence may have softened from ${prev.confidence} to ${theory.confidence}.`,
            supportingIds,
            delta,
          ),
        );
      }

      const wasActive =
        prev.status === "active" ||
        prev.status === "strengthening" ||
        prev.status === "weakening";
      if (theory.status === "resolved" && wasActive && prev.status !== "resolved") {
        push(
          buildNotification(
            theory,
            "resolved",
            theory.resolutionNote ??
              "Your archive suggests this working theory may be settling.",
            supportingIds,
          ),
        );
      }
      if (theory.status === "retired" && prev.status !== "retired") {
        push(
          buildNotification(
            theory,
            "retired",
            theory.resolutionNote ??
              "Your archive suggests this working theory may no longer match recent moments.",
            supportingIds,
          ),
        );
      }
    }

    const newSupporting = newEntryIds(supportingIds, base.supporting);
    if (newSupporting.length > 0 && prev) {
      const anchorDay =
        latestDayKey(prev.supportingEntryIds, entriesById) ?? baselineSavedDay;
      const qualifying = newSupporting.filter((id) => {
        const day = entryDayKey(id, entriesById);
        if (!day) return false;
        return daysBetweenKeys(anchorDay, day) >= SUPPORTING_GAP_DAYS;
      });
      if (qualifying.length > 0) {
        push(
          buildNotification(
            theory,
            "new_evidence",
            qualifying.length === 1
              ? "One new supporting moment appeared after a longer gap."
              : `${qualifying.length} new supporting moments appeared after a longer gap.`,
            qualifying,
          ),
        );
      }
    }

    const newContradicting = newEntryIds(contradictingIds, base.contradicting);
    if (newContradicting.length > 0) {
      push(
        buildNotification(
          theory,
          "contradiction",
          newContradicting.length === 1
            ? "One new moment may pull against this theory."
            : `${newContradicting.length} new moments may pull against this theory.`,
          newContradicting,
        ),
      );
    }

    if (
      snapshot.predictionOutcomeKey &&
      snapshot.predictionOutcomeKey !== base.predictionKey
    ) {
      const candidateId = theory.id.replace("theory:prediction:", "");
      const item = context.predictionByCandidateId.get(candidateId);
      push(
        buildNotification(
          theory,
          "prediction_outcome",
          item?.outcomeSummary ?? "Later evidence may not match the outcome you expected.",
          supportingIds.slice(-2),
        ),
      );
    }
  }

  for (const prev of baseline.theories) {
    const current = report.all.find((t) => t.id === prev.id);
    if (!current && (prev.status === "active" || prev.status === "weakening")) {
      const stub: Theory = {
        id: prev.id,
        statement: prev.statement,
        confidence: prev.confidence,
        confidenceDelta: 0,
        supportingEvidenceCount: prev.supportingEntryIds.length,
        contradictingEvidenceCount: prev.contradictingEntryIds.length,
        createdAt: baseline.savedAt,
        updatedAt: baseline.savedAt,
        status: "resolved",
        source: prev.source,
        supportingEvidence: [],
        contradictingEvidence: [],
        whatChanged: [],
      };
      push(
        buildNotification(
          stub,
          "resolved",
          "This theory no longer appears in your current model.",
          prev.supportingEntryIds,
        ),
      );
    }
  }

  return created;
}

/** Compare current theories to discover baseline; append new notifications. */
export function generateTheoryNotifications(
  entries: JournalEntry[],
  options?: { persist?: boolean },
): TheoryNotificationGenerationReport {
  const persist = options?.persist !== false;
  const baseline = readDiscoverBaseline();

  if (!baseline) {
    return {
      generatedAt: new Date().toISOString(),
      hasBaseline: false,
      created: [],
      skippedFirstVisit: true,
    };
  }

  const created = candidatesFromComparison(baseline, entries);
  if (persist && created.length > 0) {
    appendTheoryNotifications(created);
  }

  return {
    generatedAt: new Date().toISOString(),
    hasBaseline: true,
    created,
    skippedFirstVisit: false,
  };
}
