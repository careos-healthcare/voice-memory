import { linkedAreasForEntries } from "@/lib/blind-spots/blind-spot-ranking";
import type { LifeAreaLabel } from "@/lib/blind-spots/blind-spot-ranking";
import { CONTINUITY_ARCHIVE_FALLBACK } from "@/lib/archive/continuity-reinforcement-copy";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { readTheorySnapshot } from "@/lib/theories/theory-snapshots";
import { clampConfidence } from "@/lib/theories/theory-confidence-movement";
import type {
  ContinuityReinforcementSurface,
  ContinuityStripMessage,
} from "@/types/continuity-reinforcement";
import type { JournalEntry } from "@/types/journal";
import type { Theory } from "@/types/theory";

const MONTH_DAYS = 28;

function newId(prefix: string): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return `${prefix}-${crypto.randomUUID()}`;
  }
  return `${prefix}-${Date.now()}`;
}

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function daysBetween(startIso: string, endIso: string): number {
  const start = new Date(startIso).getTime();
  const end = new Date(endIso).getTime();
  if (!Number.isFinite(start) || !Number.isFinite(end)) return 0;
  return Math.max(0, Math.floor((end - start) / 86_400_000));
}

function formatLifeAreasInline(areas: LifeAreaLabel[]): string {
  const labels = areas.slice(0, 3).map((a) => a.toLowerCase());
  if (labels.length === 0) return "";
  if (labels.length === 1) return labels[0]!;
  if (labels.length === 2) return `${labels[0]} and ${labels[1]}`;
  return `${labels.slice(0, -1).join(", ")}, and ${labels[labels.length - 1]}`;
}

function uniqueSupportingReflectionCount(theory: Theory): number {
  const ids = new Set([
    ...theory.supportingEvidence.map((q) => q.entryId),
    ...theory.contradictingEvidence.map((q) => q.entryId),
  ]);
  return ids.size;
}

function theoryFirstAppearedMessage(theory: Theory, nowIso: string): ContinuityStripMessage | null {
  const days = daysBetween(theory.createdAt, nowIso);
  if (days < 1) return null;
  return {
    id: newId("cs"),
    kind: "theory_first_appeared",
    text:
      days === 1
        ? "This theory first appeared yesterday."
        : `This theory first appeared ${days} days ago.`,
  };
}

function crossLifeAreasMessage(
  theory: Theory,
  entries: JournalEntry[],
): ContinuityStripMessage | null {
  const entryIds = [
    ...new Set([
      ...theory.supportingEvidence.map((q) => q.entryId),
      ...theory.contradictingEvidence.map((q) => q.entryId),
    ]),
  ];
  const areas = linkedAreasForEntries(entries, entryIds);
  if (areas.length < 2) return null;
  const spread = formatLifeAreasInline(areas);
  return {
    id: newId("cs"),
    kind: "cross_life_areas",
    text: `This now appears in ${spread}.`,
  };
}

function confidenceChangeMessage(theory: Theory, nowIso: string): ContinuityStripMessage | null {
  const snapshot = readTheorySnapshot(theory.id);
  if (snapshot) {
    const ageDays = daysBetween(snapshot.updatedAt, nowIso);
    if (ageDays >= MONTH_DAYS) {
      const delta = clampConfidence(theory.confidence) - clampConfidence(snapshot.confidence);
      if (Math.abs(delta) >= 1) {
        const verb = delta > 0 ? "gained" : "lost";
        return {
          id: newId("cs"),
          kind: "confidence_change",
          text: `This theory has ${verb} ${Math.abs(delta)}% confidence since last month.`,
        };
      }
    }
  }

  if (theory.previousConfidence !== undefined) {
    const delta = clampConfidence(theory.confidence) - clampConfidence(theory.previousConfidence);
    if (Math.abs(delta) >= 1) {
      const verb = delta > 0 ? "gained" : "lost";
      return {
        id: newId("cs"),
        kind: "confidence_change",
        text: `This theory has ${verb} ${Math.abs(delta)}% confidence since your last visit.`,
      };
    }
  }

  return null;
}

function reflectionCountMessage(theory: Theory): ContinuityStripMessage | null {
  const count = Math.max(
    uniqueSupportingReflectionCount(theory),
    theory.supportingEvidenceCount,
  );
  if (count < 2) return null;
  return {
    id: newId("cs"),
    kind: "reflection_count",
    text: `This has appeared in ${count} separate reflections.`,
  };
}

function stillTestingMessage(theory: Theory): ContinuityStripMessage {
  return {
    id: newId("cs"),
    kind: "still_testing",
    text: "Your archive is still weighing this theory.",
  };
}

function archiveConnectingMessage(reflectionCount: number): ContinuityStripMessage {
  const text =
    reflectionCount >= 2
      ? `Your archive is connecting observations across ${reflectionCount} reflections.`
      : CONTINUITY_ARCHIVE_FALLBACK;
  return {
    id: newId("cs"),
    kind: "archive_connecting",
    text,
  };
}

function collectTheoryCandidates(
  theory: Theory,
  entries: JournalEntry[],
  nowIso: string,
): ContinuityStripMessage[] {
  return [
    theoryFirstAppearedMessage(theory, nowIso),
    crossLifeAreasMessage(theory, entries),
    confidenceChangeMessage(theory, nowIso),
    reflectionCountMessage(theory),
    stillTestingMessage(theory),
  ].filter((m): m is ContinuityStripMessage => m !== null);
}

const SURFACE_ROTATE: Record<ContinuityReinforcementSurface, number> = {
  discover: 0,
  blind_spots: 1,
  theories: 2,
  memory: 3,
  updates: 4,
};

function pickCandidate(
  candidates: ContinuityStripMessage[],
  surface: ContinuityReinforcementSurface,
): ContinuityStripMessage {
  if (candidates.length === 0) {
    return {
      id: newId("cs"),
      kind: "archive_connecting",
      text: CONTINUITY_ARCHIVE_FALLBACK,
    };
  }
  const index = SURFACE_ROTATE[surface] % candidates.length;
  return candidates[index]!;
}

export function buildContinuityStripMessage(
  entriesInput: JournalEntry[],
  surface: ContinuityReinforcementSurface,
): ContinuityStripMessage {
  const entries = eligible(entriesInput);
  const nowIso = new Date().toISOString();
  const report = buildTheoryTrackerReport(entries, { persistSnapshots: false });
  const lead = report.all[0];

  if (lead) {
    const candidates = collectTheoryCandidates(lead, entries, nowIso);
    return pickCandidate(candidates, surface);
  }

  return archiveConnectingMessage(entries.length);
}

export const CONTINUITY_REINFORCEMENT_SURFACES: ContinuityReinforcementSurface[] = [
  "discover",
  "blind_spots",
  "theories",
  "memory",
  "updates",
];
