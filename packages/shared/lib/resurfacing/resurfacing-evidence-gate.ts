import {
  runCanonicalResurfacingPipeline,
  runCanonicalPipelineForContinuity,
  runCanonicalPipelineForMemoryNote,
} from "@/lib/resurfacing/canonical-resurfacing-pipeline";
import type { BuildResurfacingEvidenceInput } from "@/lib/resurfacing/resurfacing-evidence";
import type {
  ResurfacingEvidenceGateResult,
} from "@/types/resurfacing-evidence";
import type { MemoryNote } from "@/types/memory-note";
import type { JournalEntry } from "@/types/journal";

export const MIN_GATE_CONFIDENCE = 58;
export const MIN_GATE_EVIDENCE_SCORE = 28;

/** @deprecated Use runCanonicalResurfacingPipeline — kept for internal/tests. */
export function applyResurfacingEvidenceGate(
  input: BuildResurfacingEvidenceInput & { displayText?: string; sourceEntryIds?: string[] },
): ResurfacingEvidenceGateResult {
  const result = runCanonicalResurfacingPipeline({
    quote: input.quote,
    entries: input.entries,
    note: input.note,
    appearances: input.appearances,
    gapDays: input.gapDays,
    threadType: input.threadType,
    displayText: input.displayText,
    missingTranscript: input.missingTranscript,
    sourceEntryIds: input.sourceEntryIds,
  });
  return {
    show: result.show,
    finalConfidence: result.finalConfidence,
    suppressionReasons: result.suppressionReasons,
    safeDisplayMode: result.safeDisplayMode,
    evidence: result.evidence,
    whySurfaced: result.whySurfacedLines[0] ?? "",
    displayText: result.callbackText,
  };
}

export function applyEvidenceGateForMemoryNote(
  note: MemoryNote,
  entries: JournalEntry[],
): ResurfacingEvidenceGateResult {
  const result = runCanonicalPipelineForMemoryNote(note, entries);
  return {
    show: result.show,
    finalConfidence: result.finalConfidence,
    suppressionReasons: result.suppressionReasons,
    safeDisplayMode: result.safeDisplayMode,
    evidence: result.evidence,
    whySurfaced: result.whySurfacedLines[0] ?? "",
    displayText: result.callbackText,
  };
}

export function gateMemoryNoteCallback(
  note: MemoryNote,
  entries: JournalEntry[],
): MemoryNote | null {
  const result = runCanonicalPipelineForMemoryNote(note, entries);
  if (!result.show) return null;
  return {
    ...note,
    confidence: result.finalConfidence,
    evidenceReason: result.whySurfacedLines[0],
    text: result.callbackText,
  };
}

export function applyEvidenceGateForContinuity(input: {
  quote: string;
  appearances: number;
  gapDays?: number;
  threadType?: BuildResurfacingEvidenceInput["threadType"];
  entries?: JournalEntry[];
}): ResurfacingEvidenceGateResult {
  const result = runCanonicalPipelineForContinuity(input);
  return {
    show: result.show,
    finalConfidence: result.finalConfidence,
    suppressionReasons: result.suppressionReasons,
    safeDisplayMode: result.safeDisplayMode,
    evidence: result.evidence,
    whySurfaced: result.whySurfacedLines[0] ?? "",
    displayText: result.callbackText,
  };
}
