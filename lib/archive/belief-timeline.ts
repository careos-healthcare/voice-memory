import { linkedAreasForEntries } from "@/lib/blind-spots/blind-spot-ranking";
import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { ARCHIVE_BELIEF_STATUS_LABEL } from "@/lib/archive/archive-belief-copy";
import {
  deriveTimelineNote,
  historyToTimelinePoints,
  periodKeyFromIso,
  periodLabelFromKey,
  readBeliefTimelineHistory,
} from "@/lib/archive/belief-timeline-storage";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { theoryToPersonalTheory } from "@/lib/theories/personal-theory-map";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { BeliefChangeTimeline, BeliefTimelinePoint } from "@/types/belief-timeline";
import type { JournalEntry } from "@/types/journal";
import type { Theory } from "@/types/theory";

function eligible(entries: JournalEntry[]): JournalEntry[] {
  if (!Array.isArray(entries)) return [];
  return entries.filter((e) => e.reflectionPending !== true);
}

function pickLead(theories: Theory[]): Theory | null {
  if (theories.length === 0) return null;
  const active = theories.filter(
    (t) => t.status === "active" || t.status === "strengthening" || t.status === "weakening",
  );
  const pool = active.length > 0 ? active : theories;
  return pool.slice().sort((a, b) => b.confidence - a.confidence)[0] ?? null;
}

function monthNote(
  current: Theory,
  previous: Theory | null,
  entries: JournalEntry[],
): string {
  const base = deriveTimelineNote(current, previous);
  if (base !== ARCHIVE_BELIEF_STATUS_LABEL[theoryToPersonalTheory(current).status]) {
    return base;
  }

  if (previous) {
    const entryIds = [
      ...new Set([
        ...current.supportingEvidence.map((q) => q.entryId),
        ...current.contradictingEvidence.map((q) => q.entryId),
      ]),
    ];
    const areas = linkedAreasForEntries(entries, entryIds);
    if (areas.length >= 2) {
      const labels = areas.slice(0, 2).map((a) => a.toLowerCase());
      return `Appeared in ${labels[0]} and ${labels[1]}`;
    }
    if (areas.length === 1) {
      return `New evidence from ${areas[0]!.toLowerCase()}`;
    }
  }

  if (current.supportingEvidenceCount >= 3 && !previous) {
    return "Evidence growing";
  }

  return ARCHIVE_BELIEF_STATUS_LABEL[theoryToPersonalTheory(current).status];
}

function reconstructMonthlyTimeline(entries: JournalEntry[]): BeliefTimelinePoint[] {
  const sorted = [...eligible(entries)].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
  if (sorted.length < 2) return [];

  const monthBuckets = new Map<string, JournalEntry[]>();
  for (const entry of sorted) {
    const key = periodKeyFromIso(entry.createdAt);
    const bucket = monthBuckets.get(key) ?? [];
    bucket.push(entry);
    monthBuckets.set(key, bucket);
  }

  const keys = [...monthBuckets.keys()].sort();
  const points: BeliefTimelinePoint[] = [];
  let cumulative: JournalEntry[] = [];
  let previousLead: Theory | null = null;

  for (const key of keys) {
    cumulative = [...cumulative, ...(monthBuckets.get(key) ?? [])];
    const report = buildTheoryTrackerReport(cumulative, { persistSnapshots: false });
    const lead = pickLead(report.all);
    if (!lead) continue;

    const note = monthNote(lead, previousLead, cumulative);
    const personal = theoryToPersonalTheory(lead);

    const entryIds = [
      ...new Set([
        ...lead.supportingEvidence.map((q) => q.entryId),
        ...lead.contradictingEvidence.map((q) => q.entryId),
      ]),
    ];
    const areas = linkedAreasForEntries(cumulative, entryIds);

    points.push({
      id: `bt-${key}`,
      periodKey: key,
      periodLabel: periodLabelFromKey(key),
      confidence: lead.confidence,
      statusLabel: ARCHIVE_BELIEF_STATUS_LABEL[personal.status],
      note,
      whatChanged: note,
      evidenceQuoteCount:
        lead.supportingEvidence.length + lead.contradictingEvidence.length,
      lifeAreas: areas.slice(0, 4),
      hasContradiction: lead.contradictingEvidence.length > 0,
      hasCostEvidence: lead.whatChanged.some((w) => /cost|prediction fail/i.test(w)),
      at: cumulative[cumulative.length - 1]!.createdAt,
    });
    previousLead = lead;
  }

  return points;
}

function mergeTimelinePoints(
  stored: BeliefTimelinePoint[],
  reconstructed: BeliefTimelinePoint[],
): BeliefTimelinePoint[] {
  const byKey = new Map<string, BeliefTimelinePoint>();
  for (const p of reconstructed) {
    byKey.set(p.periodKey, p);
  }
  for (const p of stored) {
    byKey.set(p.periodKey, p);
  }
  return [...byKey.values()].sort((a, b) => a.periodKey.localeCompare(b.periodKey));
}

export function buildBeliefChangeTimeline(
  entriesInput?: JournalEntry[],
  options?: { theoryId?: string },
): BeliefChangeTimeline | null {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  const belief = buildArchiveBeliefView(entries);
  if (!belief) return null;

  const theoryId = options?.theoryId ?? belief.theoryId;
  const stored = historyToTimelinePoints(readBeliefTimelineHistory(theoryId));
  const reconstructed = reconstructMonthlyTimeline(entries);
  const points = mergeTimelinePoints(stored, reconstructed).slice(-10);

  if (points.length < 2) return null;

  return { theoryId, points };
}
