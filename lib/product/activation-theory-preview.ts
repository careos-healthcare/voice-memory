import { buildEmergingPatterns } from "@/lib/blind-spots/emerging-patterns";
import { buildMiniWowReport } from "@/lib/blind-spots/mini-wow";
import { buildPatternCandidatesRelaxed, type PatternInsight } from "@/lib/patterns/pattern-engine";
import type { ActivationTheoryPreview } from "@/types/activation-theory-preview";
import type { JournalEntry } from "@/types/journal";

export const ACTIVATION_THEORY_PREVIEW_TITLE = "What ArchiveMe may be starting to see";
export const ACTIVATION_THEORY_PREVIEW_DISCLAIMER = "Early signal, not a conclusion.";
export const ACTIVATION_THEORY_PREVIEW_CONFIDENCE = "Low confidence";

export const FORBIDDEN_THEORY_PREVIEW =
  /\b(diagnos|disorder|patholog|clinical|trauma|therapy|counsel|coach|treatment|mental health|you are|you're always|always |root cause|guaranteed|certainly)\b/i;

const NEXT_REFLECTION_COPY =
  "Your next moment helps ArchiveMe check whether this is real or just noise.";

const FALLBACK_THEORY =
  "You may be circling the same concern before there is enough history to name it.";

function eligibleEntries(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function unlockCopyFor(remaining: number): string {
  if (remaining === 1) {
    return "1 more moment before ArchiveMe can weigh this with confidence.";
  }
  return "2 more moments before ArchiveMe can weigh this with confidence.";
}

function sanitizeTheory(text: string): string {
  let sentence = text.replace(/\s+/g, " ").trim();
  if (!sentence) return FALLBACK_THEORY;
  if (FORBIDDEN_THEORY_PREVIEW.test(sentence)) return FALLBACK_THEORY;
  if (!/\b(may|might|possible)\b/i.test(sentence)) {
    const lower = sentence.charAt(0).toLowerCase() + sentence.slice(1);
    sentence = lower.match(/^(you|i)\b/i) ? `You may be ${lower}` : `This may be possible: ${lower}`;
  }
  if (!sentence.endsWith(".")) sentence += ".";
  return sentence;
}

function theoryFromInsight(insight: PatternInsight): string {
  const detail = insight.detail.replace(/\s+/g, " ").trim();
  const title = insight.title.replace(/\s+/g, " ").trim();
  const raw =
    detail.length > 24
      ? detail
      : title.length > 12
        ? title
        : `a possible thread around ${insight.sourceKey.replace(/-/g, " ")}`;
  return sanitizeTheory(raw);
}

function pickPreviewSignal(
  entries: JournalEntry[],
): { possibleTheory: string; evidenceCount: number } | null {
  const relaxed = buildPatternCandidatesRelaxed(entries, { limit: 8 });
  const best = relaxed.find(
    (i) => !i.specificity.isWeakOrGeneric && i.entryIds.length >= 2,
  );
  if (best) {
    return { possibleTheory: theoryFromInsight(best), evidenceCount: best.entryIds.length };
  }

  const emerging = buildEmergingPatterns(entries)[0];
  if (emerging?.hypothesis) {
    return {
      possibleTheory: sanitizeTheory(emerging.hypothesis),
      evidenceCount: emerging.evidenceQuotes.length,
    };
  }

  const miniWow = buildMiniWowReport(entries);
  if (miniWow.showPanel && miniWow.body.trim()) {
    return {
      possibleTheory: sanitizeTheory(miniWow.body),
      evidenceCount: Math.max(miniWow.evidenceQuotes.length, 2),
    };
  }

  return null;
}

/** Early theory preview for the 3→4→5 reflection bottleneck only. */
export function buildActivationTheoryPreview(
  entries: JournalEntry[],
): ActivationTheoryPreview | null {
  const eligible = eligibleEntries(entries);
  const reflectionCount = eligible.length;

  if (reflectionCount < 3 || reflectionCount >= 5) return null;

  const signal = pickPreviewSignal(eligible);
  const remainingCount = 5 - reflectionCount;

  return {
    title: ACTIVATION_THEORY_PREVIEW_TITLE,
    possibleTheory: signal?.possibleTheory ?? FALLBACK_THEORY,
    confidenceLabel: ACTIVATION_THEORY_PREVIEW_CONFIDENCE,
    evidenceCount: signal?.evidenceCount ?? reflectionCount,
    reflectionCount,
    remainingCount,
    unlockCopy: unlockCopyFor(remainingCount),
    disclaimer: ACTIVATION_THEORY_PREVIEW_DISCLAIMER,
    nextReflectionCopy: NEXT_REFLECTION_COPY,
  };
}

export function passesTheoryPreviewCopyGate(preview: ActivationTheoryPreview): boolean {
  const blob = [
    preview.possibleTheory,
    preview.unlockCopy,
    preview.nextReflectionCopy,
    preview.disclaimer,
  ].join(" ");
  return (
    !FORBIDDEN_THEORY_PREVIEW.test(blob) &&
    preview.disclaimer.includes(ACTIVATION_THEORY_PREVIEW_DISCLAIMER)
  );
}
