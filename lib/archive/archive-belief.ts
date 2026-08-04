import { buildBlindSpotAccelerationReport } from "@/lib/blind-spots/blind-spot-acceleration";
import {
  buildDiscoverEvidenceContext,
  theoryToEvidenceBaseline,
} from "@/lib/discover/theory-evidence-snapshot";
import {
  ARCHIVE_BELIEF_STATUS_EXPLANATION,
  ARCHIVE_BELIEF_STATUS_LABEL,
} from "@/lib/archive/archive-belief-copy";
import {
  ARCHIVE_EMOTIONAL,
  emotionalConfidenceLine,
  emotionalWeakenedLine,
} from "@/lib/archive/archive-emotional-copy";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { theoryToPersonalTheory } from "@/lib/theories/personal-theory-map";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type {
  ArchiveBeliefChangeLine,
  ArchiveBeliefEvidence,
  ArchiveBeliefView,
} from "@/types/archive-belief";
import type { JournalEntry } from "@/types/journal";
import type { Theory } from "@/types/theory";

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function pickLeadTheory(theories: Theory[]): Theory | null {
  if (theories.length === 0) return null;
  const active = theories.filter(
    (t) => t.status === "active" || t.status === "strengthening" || t.status === "weakening",
  );
  const pool = active.length > 0 ? active : theories;
  return pool.slice().sort((a, b) => b.confidence - a.confidence)[0] ?? null;
}

function lineId(prefix: string): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return `${prefix}-${crypto.randomUUID()}`;
  }
  return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

function formatWhatChangedForBelief(raw: string): string {
  const trimmed = raw.replace(/\s+/g, " ").trim();
  if (!trimmed) return "";
  if (/^confidence/i.test(trimmed) || /confidence increased/i.test(trimmed)) {
    return emotionalConfidenceLine();
  }
  if (/confidence decreased/i.test(trimmed)) {
    return emotionalWeakenedLine();
  }
  if (/contradict/i.test(trimmed)) return "Contradicting evidence appeared";
  if (/mixed evidence/i.test(trimmed)) return "Contradicting evidence appeared";
  if (/new because/i.test(trimmed)) return trimmed.replace(/^this is new because/i, "New evidence");
  return trimmed.charAt(0).toUpperCase() + trimmed.slice(1);
}

function buildBeliefChangeLines(
  theory: Theory,
  entries: JournalEntry[],
): ArchiveBeliefChangeLine[] {
  const context = buildDiscoverEvidenceContext(entries);
  const snapshot = theoryToEvidenceBaseline(theory, entries, context);
  const seen = new Set<string>();
  const lines: ArchiveBeliefChangeLine[] = [];

  const push = (text: string) => {
    const normalized = text.trim();
    if (!normalized || seen.has(normalized)) return;
    seen.add(normalized);
    lines.push({ id: lineId("abl"), text: `+ ${normalized}` });
  };

  for (const raw of theory.whatChanged) {
    const formatted = formatWhatChangedForBelief(raw);
    if (formatted) push(formatted);
  }

  if (
    theory.previousConfidence !== undefined &&
    Math.abs(theory.confidenceDelta) >= 1
  ) {
    push(
      theory.confidenceDelta > 0
        ? emotionalConfidenceLine()
        : emotionalWeakenedLine(),
    );
  }

  const areas = snapshot.lifeAreas;
  if (areas.length >= 2) {
    push(
      `Appeared in ${areas
        .slice(0, 2)
        .map((a) => a.toLowerCase())
        .join(" and ")}`,
    );
  } else if (areas.length === 1) {
    push(`New evidence from ${areas[0]!.toLowerCase()}`);
  }

  if (theory.status === "weakening") push(ARCHIVE_EMOTIONAL.theoryWeakened);
  if (theory.status === "strengthening" && lines.length === 0) {
    push("Recent saved moments support this theory");
  }
  if (theory.contradictingEvidenceCount > 0 && !seen.has("+ Contradicting evidence appeared")) {
    push("Contradicting evidence appeared");
  }

  return lines.slice(0, 6);
}

function predictionFailureLines(
  theory: Theory,
  entries: JournalEntry[],
): string[] {
  if (!theory.id.startsWith("theory:prediction:")) return [];
  const candidateId = theory.id.slice("theory:prediction:".length);
  const report = buildBlindSpotAccelerationReport(entries);
  const item = report.predictionReview.items.find(
    (row) => row.candidate.id === candidateId,
  );
  if (!item) return [];
  if (item.outcomeStatus === "aligned") return [];
  return [item.outcomeSummary.trim() || "Later saved moments may not match what you expected."];
}

function buildBeliefEvidence(
  theory: Theory,
  entries: JournalEntry[],
): ArchiveBeliefEvidence {
  const context = buildDiscoverEvidenceContext(entries);
  const snapshot = theoryToEvidenceBaseline(theory, entries, context);
  return {
    supportingQuotes: theory.supportingEvidence.slice(0, 6),
    contradictingQuotes: theory.contradictingEvidence.slice(0, 6),
    lifeAreas: snapshot.lifeAreas,
    costEvidenceLines: snapshot.costEvidenceLines,
    predictionFailureLines: predictionFailureLines(theory, entries),
  };
}

export function buildArchiveBeliefView(
  entriesInput?: JournalEntry[],
): ArchiveBeliefView | null {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  if (entries.length < 2) return null;

  const report = buildTheoryTrackerReport(entries, { persistSnapshots: false });
  const lead = pickLeadTheory(report.all);
  if (!lead) return null;

  const personal = theoryToPersonalTheory(lead);
  return {
    theoryId: lead.id,
    source: lead.source,
    belief: personal.hypothesis,
    confidence: personal.confidence,
    status: personal.status,
    statusLabel: ARCHIVE_BELIEF_STATUS_LABEL[personal.status],
    statusExplanation: ARCHIVE_BELIEF_STATUS_EXPLANATION[personal.status],
    changeLines: buildBeliefChangeLines(lead, entries),
    evidence: buildBeliefEvidence(lead, entries),
  };
}
