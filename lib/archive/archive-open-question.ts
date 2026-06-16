import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { ArchiveOpenQuestionView } from "@/types/living-archive";
import type { JournalEntry } from "@/types/journal";

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function lineId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `open-q-${Date.now()}`;
}

function beliefToEvaluatingQuestion(belief: string): string {
  const trimmed = belief.replace(/\s+/g, " ").trim().replace(/\.$/, "");
  if (trimmed.includes("?")) return trimmed;
  if (/^whether /i.test(trimmed)) return trimmed.charAt(0).toUpperCase() + trimmed.slice(1) + ".";
  return `Whether ${trimmed.charAt(0).toLowerCase() + trimmed.slice(1)}.`;
}

function beliefToUnknownQuestion(belief: string): string {
  const trimmed = belief.replace(/\s+/g, " ").trim().replace(/\.$/, "");
  if (trimmed.includes("?")) return trimmed;
  const core = trimmed.replace(/^I /i, "").replace(/^my /i, "my ");
  return `Does ${core.charAt(0).toLowerCase() + core.slice(1)}?`;
}

export function buildArchiveOpenQuestions(
  entriesInput?: JournalEntry[],
): ArchiveOpenQuestionView[] {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  const belief = buildArchiveBeliefView(entries);
  if (!belief || entries.length < 3) return [];

  const questions: ArchiveOpenQuestionView[] = [];

  if (belief.status === "under_review" || belief.confidence < 52) {
    questions.push({
      id: lineId(),
      lead: "The archive is still evaluating:",
      text: beliefToEvaluatingQuestion(belief.belief),
    });
  }

  if (belief.evidence.contradictingQuotes.length > 0 && questions.length === 0) {
    questions.push({
      id: lineId(),
      lead: "The archive still does not know:",
      text: beliefToUnknownQuestion(belief.belief),
    });
  }

  if (belief.status === "weakening" && questions.length < 2) {
    questions.push({
      id: lineId(),
      lead: "The archive still does not know:",
      text: "How recent reflections change this belief.",
    });
  }

  return questions.slice(0, 2);
}
