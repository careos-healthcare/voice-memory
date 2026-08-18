import { ARCHIVE_ATTACHMENT_STRONG_LEVELS } from "@/lib/archive/archive-attachment-copy";
import { readArchiveAttachmentRecords } from "@/lib/archive/archive-attachment";
import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { buildArchiveStateObject } from "@/lib/archive/archive-state-object";
import { buildBeliefSurvivalView } from "@/lib/archive/belief-survival";
import { readArchiveDisclosureStorage } from "@/lib/archive/archive-disclosure-level";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type {
  DistributionWorthyMoment,
  TransformationMomentType,
} from "@/types/distribution";
import type { JournalEntry } from "@/types/journal";

export const DISTRIBUTION_MOMENTS_KEY = "voicememory_distribution_moments";
export const DISTRIBUTION_MOMENTS_SEEN_KEY = "voicememory_distribution_moments_seen";

const MAX_MOMENTS = 80;

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function newId(prefix: string): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return `${prefix}-${crypto.randomUUID()}`;
  }
  return `${prefix}-${Date.now()}`;
}

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

export function readDistributionMoments(): DistributionWorthyMoment[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(DISTRIBUTION_MOMENTS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as DistributionWorthyMoment[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeDistributionMoments(rows: DistributionWorthyMoment[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(
    DISTRIBUTION_MOMENTS_KEY,
    JSON.stringify(rows.slice(-MAX_MOMENTS)),
  );
}

function hasMomentType(
  rows: DistributionWorthyMoment[],
  type: TransformationMomentType,
  theoryId?: string,
): boolean {
  return rows.some(
    (r) => r.type === type && (theoryId ? r.theoryId === theoryId : true),
  );
}

function pushMoment(
  rows: DistributionWorthyMoment[],
  moment: Omit<DistributionWorthyMoment, "id" | "detectedAt" | "distributionWorthy">,
): DistributionWorthyMoment[] {
  if (hasMomentType(rows, moment.type, moment.theoryId)) return rows;
  return [
    ...rows,
    {
      ...moment,
      id: newId("dm"),
      detectedAt: new Date().toISOString(),
      distributionWorthy: true,
    },
  ];
}

/** Detect archive transformation moments from current journal state. */
export function detectTransformationMoments(
  entriesInput?: JournalEntry[],
): DistributionWorthyMoment[] {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  const existing = readDistributionMoments();
  if (entries.length === 0) return existing;

  let rows = [...existing];
  const belief = buildArchiveBeliefView(entries);
  const state = buildArchiveStateObject(entries);
  const report = buildTheoryTrackerReport(entries, { persistSnapshots: false });
  const lead = belief
    ? report.all.find((t) => t.id === belief.theoryId) ?? report.all[0]
    : report.all[0];

  if (belief && !hasMomentType(rows, "first_belief")) {
    rows = pushMoment(rows, {
      type: "first_belief",
      theoryId: belief.theoryId,
      headline: "Your archive formed its first working belief.",
      meta: { confidence: String(belief.confidence) },
    });
  }

  if (lead && lead.whatChanged.length > 0 && !hasMomentType(rows, "belief_change", lead.id)) {
    rows = pushMoment(rows, {
      type: "belief_change",
      theoryId: lead.id,
      headline: "Your archive updated what it believes about you.",
      meta: { changes: String(lead.whatChanged.length) },
    });
  }

  if (
    lead &&
    (lead.contradictingEvidence.length > 0 || lead.status === "weakening") &&
    !hasMomentType(rows, "belief_challenged", lead.id)
  ) {
    rows = pushMoment(rows, {
      type: "belief_challenged",
      theoryId: lead.id,
      headline: "Your archive is weighing challenging evidence.",
      meta: { contradictions: String(lead.contradictingEvidence.length) },
    });
  }

  const disclosure = readArchiveDisclosureStorage();
  if (
    state &&
    disclosure.archiveVisitCount >= 2 &&
    state.changeSummary !== "Nothing notable has shifted since your last visit." &&
    !hasMomentType(rows, "archive_changed_while_away")
  ) {
    rows = pushMoment(rows, {
      type: "archive_changed_while_away",
      theoryId: lead?.id,
      headline: "Your archive changed while you were away.",
    });
  }

  if (
    lead &&
    lead.contradictingEvidence.length > 0 &&
    !hasMomentType(rows, "first_contradiction")
  ) {
    rows = pushMoment(rows, {
      type: "first_contradiction",
      theoryId: lead.id,
      headline: "Your archive recorded its first contradiction.",
      meta: { count: String(lead.contradictingEvidence.length) },
    });
  }

  const strongAttachment = readArchiveAttachmentRecords().find((r) =>
    ARCHIVE_ATTACHMENT_STRONG_LEVELS.includes(r.level),
  );
  if (strongAttachment && !hasMomentType(rows, "first_strong_attachment")) {
    rows = pushMoment(rows, {
      type: "first_strong_attachment",
      headline: "You reported strong attachment to your archive.",
      meta: { level: strongAttachment.level },
    });
  }

  if (
    disclosure.archiveVisitCount >= 2 &&
    state &&
    state.changeSummary !== "Nothing notable has shifted since your last visit." &&
    !hasMomentType(rows, "first_return_after_archive_change")
  ) {
    rows = pushMoment(rows, {
      type: "first_return_after_archive_change",
      theoryId: lead?.id,
      headline: "You returned to find your archive had moved.",
    });
  }

  return rows;
}

/** Persist newly detected distribution-worthy moments. */
export function syncTransformationMoments(
  entriesInput?: JournalEntry[],
): DistributionWorthyMoment[] {
  const detected = detectTransformationMoments(entriesInput);
  const prior = readDistributionMoments();
  const mergedIds = new Set(prior.map((r) => r.id));
  const added = detected.filter((r) => !mergedIds.has(r.id));
  if (added.length === 0 && detected.length === prior.length) return prior;
  writeDistributionMoments(detected);
  return detected;
}

export function latestDistributionMoment(
  type?: TransformationMomentType,
): DistributionWorthyMoment | null {
  const rows = readDistributionMoments();
  const filtered = type ? rows.filter((r) => r.type === type) : rows;
  return filtered[filtered.length - 1] ?? null;
}

export function distributionMomentsForShare(): DistributionWorthyMoment[] {
  return readDistributionMoments().filter((r) => r.distributionWorthy);
}

export function clearDistributionMomentsForEval(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(DISTRIBUTION_MOMENTS_KEY);
  localStorage.removeItem(DISTRIBUTION_MOMENTS_SEEN_KEY);
}
