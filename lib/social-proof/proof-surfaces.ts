import { calibratePrimaryNote, type SilenceSurface } from "@/lib/refinement/silence-calibration";
import {
  markSilenceIntelligenceSuppressed,
  shouldSuppressSilenceIntelligenceSurface,
} from "@/lib/restraint/silence-intelligence";
import { buildEligibleProofSnippets } from "@/lib/social-proof/emotional-proof";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { EmotionalProofSnippet } from "@/types/social-proof";
import type { MemoryNote } from "@/types/memory-note";

export type EmotionalProofSurface =
  | "entry_revisit"
  | "account"
  | "archive"
  | "onboarding_complete";

const SURFACE_TO_SILENCE: Record<EmotionalProofSurface, SilenceSurface> = {
  entry_revisit: "entry_revisit",
  account: "memory",
  archive: "memory",
  onboarding_complete: "memory",
};

function proofToNote(snippet: EmotionalProofSnippet): MemoryNote {
  return {
    id: snippet.id,
    text: snippet.text,
    category: "returned",
    confidence: Math.min(88, Math.round(snippet.strength)),
  };
}

/** Pick at most one quiet proof line for a surface, routed through silence calibration. */
export function pickEmotionalProofLine(
  surface: EmotionalProofSurface,
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): string | null {
  if (shouldSuppressSilenceIntelligenceSurface("emotional_proof")) {
    markSilenceIntelligenceSuppressed();
    return null;
  }

  const snippets = buildEligibleProofSnippets(entries);
  if (snippets.length === 0) return null;

  const notes = snippets.map(proofToNote);
  const calibrated = calibratePrimaryNote(notes, entries, SURFACE_TO_SILENCE[surface]);
  return calibrated?.text ?? null;
}

export function pickEmotionalProofSnippet(
  surface: EmotionalProofSurface,
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): EmotionalProofSnippet | null {
  const text = pickEmotionalProofLine(surface, entries);
  if (!text) return null;
  return buildEligibleProofSnippets(entries).find((row) => row.text === text) ?? null;
}
