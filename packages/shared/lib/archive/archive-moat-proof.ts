import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { buildBeliefSurvivalView } from "@/lib/archive/belief-survival";
import { buildContradictionHistoryView } from "@/lib/archive/contradiction-history";
import { buildEvidenceArchiveStats } from "@/lib/archive/evidence-archive-stats";
import { readBeliefTimelineHistory } from "@/lib/archive/belief-timeline-storage";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

export interface ArchiveMoatProofItem {
  id: string;
  question: string;
  answer: string;
}

export interface ArchiveMoatProofView {
  summaryLine: string;
  items: ArchiveMoatProofItem[];
  theoryId?: string;
}

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function newId(prefix: string): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return `${prefix}-${crypto.randomUUID()}`;
  }
  return `${prefix}-${Date.now()}`;
}

function reconstructabilityVerdict(
  reflectionCount: number,
  spanDays: number,
  changeCount: number,
  contradictions: number,
): "low" | "moderate" | "high" {
  const score =
    (reflectionCount >= 10 ? 2 : reflectionCount >= 5 ? 1 : 0) +
    (spanDays >= 60 ? 2 : spanDays >= 21 ? 1 : 0) +
    (changeCount >= 2 ? 1 : 0) +
    (contradictions >= 1 ? 1 : 0);
  if (score >= 5) return "high";
  if (score >= 3) return "moderate";
  return "low";
}

function answerForVerdict(
  tool: "chat_tool" | "notes" | "journal",
  verdict: "low" | "moderate" | "high",
  detail: string,
): string {
  if (verdict === "high") {
    if (tool === "chat_tool") {
      return `Unlikely from one prompt — ${detail}`;
    }
    if (tool === "notes") {
      return `Unlikely from scattered notes — ${detail}`;
    }
    return `Unlikely from a linear journal — ${detail}`;
  }
  if (verdict === "moderate") {
    return `Partially — ${detail} A general tool would miss belief-level change tracking.`;
  }
  if (tool === "journal") {
    return `Not yet — ${detail} More reflections will make recreation harder.`;
  }
  return `Not yet — ${detail}`;
}

export function buildArchiveMoatProofView(
  entriesInput?: JournalEntry[],
): ArchiveMoatProofView | null {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  if (entries.length < 2) return null;

  const belief = buildArchiveBeliefView(entries);
  const stats = buildEvidenceArchiveStats(entries);
  const survival = belief
    ? buildBeliefSurvivalView(entries, { theoryId: belief.theoryId })
    : null;
  const report = buildTheoryTrackerReport(entries, { persistSnapshots: false });
  const lead = belief
    ? report.all.find((t) => t.id === belief.theoryId) ?? report.all[0]
    : report.all[0];
  if (!lead) return null;

  const reflectionCount = Math.max(
    survival?.reflectionsSupporting ?? 0,
    lead.supportingEvidenceCount,
    stats.reflectionCount,
  );
  const spanDays = survival?.daysAlive ?? stats.daysCovered ?? 1;
  const timelineChanges = readBeliefTimelineHistory(lead.id).length;
  const changeCount = Math.max(
    timelineChanges,
    lead.whatChanged?.length ?? 0,
    belief?.changeLines.length ?? 0,
  );
  const contradictions = Math.max(
    lead.contradictingEvidence.length,
    survival?.contradictionsSurvived ?? 0,
  );
  const contradictionView = buildContradictionHistoryView(entries, {
    theoryId: lead.id,
  });

  const detail = `this belief has evolved across ${reflectionCount} reflection${reflectionCount === 1 ? "" : "s"} over ${spanDays} day${spanDays === 1 ? "" : "s"}.`;
  const verdict = reconstructabilityVerdict(
    reflectionCount,
    spanDays,
    changeCount,
    contradictions,
  );

  const items: ArchiveMoatProofItem[] = [
    {
      id: newId("moat"),
      question: "Could a one-off chat tool reconstruct this?",
      answer: answerForVerdict("chat_tool", verdict, detail),
    },
    {
      id: newId("moat"),
      question: "Could Notes reconstruct this?",
      answer: answerForVerdict("notes", verdict, detail),
    },
    {
      id: newId("moat"),
      question: "Could a journal reconstruct this?",
      answer: answerForVerdict(
        "journal",
        contradictionView ? "high" : verdict,
        contradictionView
          ? `${detail} Contradiction history is on record.`
          : detail,
      ),
    },
  ];

  return {
    theoryId: lead.id,
    summaryLine: `This belief has evolved across ${reflectionCount} reflections over ${spanDays} days.`,
    items,
  };
}
