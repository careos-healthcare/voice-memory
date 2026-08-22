import type { ArchiveGrammarSection } from "@/lib/design/archive-page-grammar";

/**
 * Visual weight — belief dominates; supporting context must not outweigh belief.
 */
export const ARCHIVE_VISUAL_WEIGHT_ORDER = [
  "belief",
  "trust",
  "change",
  "evidence",
  "context",
] as const;

export type ArchiveVisualWeightBand = (typeof ARCHIVE_VISUAL_WEIGHT_ORDER)[number];

const WEIGHT_SCORE: Record<ArchiveVisualWeightBand, number> = {
  belief: 100,
  trust: 80,
  change: 60,
  evidence: 40,
  context: 20,
};

const GRAMMAR_TO_WEIGHT: Partial<Record<ArchiveGrammarSection, ArchiveVisualWeightBand>> = {
  current_state: "belief",
  change: "change",
  evidence: "evidence",
  supporting_context: "context",
  identity: "belief",
  action: "context",
};

const GRAVITY_TO_WEIGHT: Record<string, ArchiveVisualWeightBand> = {
  identity: "belief",
  belief: "belief",
  change: "change",
  timeline: "evidence",
  evidence: "evidence",
  utilities: "context",
  trust: "trust",
};

export type SectionWeightScore = {
  section: string;
  band: ArchiveVisualWeightBand;
  score: number;
};

export type VisualWeightAuditResult = {
  ok: boolean;
  sections: SectionWeightScore[];
  violations: string[];
};

export function scoreVisualWeightBand(band: ArchiveVisualWeightBand): number {
  return WEIGHT_SCORE[band];
}

export function auditVisualWeightFromSource(source: string, label: string): VisualWeightAuditResult {
  const sections: SectionWeightScore[] = [];
  const re = /data-(?:archive-section|gravity|archive-grammar-section)=["']([^"']+)["']/g;
  let match: RegExpExecArray | null;
  while ((match = re.exec(source)) !== null) {
    const raw = match[1];
    const band =
      GRAMMAR_TO_WEIGHT[raw as ArchiveGrammarSection] ??
      GRAVITY_TO_WEIGHT[raw] ??
      "context";
    sections.push({ section: raw, band, score: scoreVisualWeightBand(band) });
  }

  const violations: string[] = [];
  const belief = sections.filter((s) => s.band === "belief");
  const context = sections.filter((s) => s.band === "context");

  if (belief.length && context.length) {
    const maxBelief = Math.max(...belief.map((s) => s.score));
    const maxContext = Math.max(...context.map((s) => s.score));
    if (maxContext >= maxBelief) {
      violations.push(`${label}: supporting sections outweigh belief`);
    }
  }

  for (let i = 0; i < sections.length - 1; i++) {
    const a = sections[i];
    const b = sections[i + 1];
    const rankA = ARCHIVE_VISUAL_WEIGHT_ORDER.indexOf(a.band);
    const rankB = ARCHIVE_VISUAL_WEIGHT_ORDER.indexOf(b.band);
    if (rankA > rankB && a.band !== "context" && b.band !== "context") {
      violations.push(`${label}: ${b.band} appears before ${a.band} in visual flow`);
    }
  }

  return { ok: violations.length === 0, sections, violations };
}
