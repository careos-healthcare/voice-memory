import { gateContinuityQuote } from "@/lib/continuity/continuity-quality-gate";
import { getMergedFeedbackSummary } from "@/lib/resurfacing/merged-feedback-client";
import {
  buildResurfacingEvidence,
  type BuildResurfacingEvidenceInput,
} from "@/lib/resurfacing/resurfacing-evidence";
import { applyAmbiguityFailsafePolicy } from "@/lib/resurfacing/resurfacing-ambiguity-policy";
import { formatWhySurfacedFromEvidence } from "@/lib/resurfacing/why-surfaced-evidence";
import { passesOverconfidentCopyGate } from "@/lib/resurfacing/overconfident-copy";
import { isStaleWithoutReinforcement } from "@/lib/resurfacing/resurfacing-staleness";
import { sanitizeResurfacingCopyForAmbiguity } from "@/lib/resurfacing/resurfacing-ambiguity";
import { hasResurfacingEvidenceAnchors } from "@/lib/resurfacing/resurfacing-evidence";
import {
  isUncertaintyBudgetExceeded,
  recordCautiousCallbackShown,
} from "@/lib/resurfacing/uncertainty-budget";
import {
  MIN_GATE_CONFIDENCE,
  MIN_GATE_EVIDENCE_SCORE,
} from "@/lib/resurfacing/resurfacing-evidence-gate";
import {
  getSpecificityThresholdBoost,
  phraseKeyFromQuote,
  topicKeyFromQuote,
  personKeyFromQuote,
  type ResurfacingFeedbackKind,
} from "@/lib/resurfacing/resurfacing-feedback";
import { buildResurfacingScores } from "@/lib/resurfacing/resurfacing-scoring";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";
import type { ResurfacingEvidence } from "@/types/resurfacing-evidence";
import type { ResurfacingSafeDisplayMode } from "@/types/resurfacing-evidence";
import type { ReturnThread } from "@/types/return-thread";

export const CANONICAL_FEEDBACK_ACTIONS: ResurfacingFeedbackKind[] = [
  "that_fits",
  "not_me",
  "wrong_topic",
  "wrong_person",
  "too_intense",
  "too_vague",
  "already_know",
  "show_less",
];

export interface CanonicalResurfacingInput {
  quote: string;
  entries?: JournalEntry[];
  note?: MemoryNote;
  appearances?: number;
  gapDays?: number;
  threadType?: ReturnThread["type"];
  displayText?: string;
  missingTranscript?: boolean;
  sourceEntryIds?: string[];
  pastQuote?: string;
  currentQuote?: string;
}

export interface CanonicalResurfacingResult {
  show: boolean;
  safeDisplayMode: ResurfacingSafeDisplayMode;
  callbackText: string;
  whySurfacedLines: string[];
  evidence: ResurfacingEvidence;
  suppressionReasons: string[];
  feedbackActions: ResurfacingFeedbackKind[];
  finalConfidence: number;
  sourceEntryIds: string[];
  phraseKey: string;
}

function recordSuppressionMetric(reason: string): void {
  if (typeof window === "undefined") return;
  void import("@/lib/resurfacing/resurfacing-metrics").then((mod) => {
    if (reason.includes("evidence") || reason.includes("no_concrete")) {
      mod.recordResurfacingMetric("callback_suppressed_no_evidence");
    } else if (reason.includes("stale")) {
      mod.recordResurfacingMetric("callback_suppressed_stale");
    } else if (reason.includes("feedback") || reason.includes("cooldown")) {
      mod.recordResurfacingMetric("callback_suppressed_feedback");
    } else if (reason.includes("ambiguity") || reason.includes("uncertainty")) {
      mod.recordResurfacingMetric("callback_suppressed_ambiguity");
    }
  });
}

/** Single canonical path for all user-facing resurfacing callbacks. */
export function runCanonicalResurfacingPipeline(
  input: CanonicalResurfacingInput,
): CanonicalResurfacingResult {
  const quote = input.quote.replace(/^["']|["']$/g, "").trim();
  const phraseKey = phraseKeyFromQuote(quote);
  const topicKey = topicKeyFromQuote(quote);
  const personKey = personKeyFromQuote(quote);
  const feedbackSummary = getMergedFeedbackSummary(phraseKey, topicKey, personKey);

  const noteForEvidence: MemoryNote | undefined =
    input.note ??
    (input.pastQuote || input.currentQuote
      ? {
          id: "eval-contradiction",
          text: input.displayText ?? input.quote,
          pastQuote: input.pastQuote,
          currentQuote: input.currentQuote ?? input.quote,
          category: "changed",
          confidence: 60,
        }
      : undefined);

  const buildInput: BuildResurfacingEvidenceInput = {
    quote: input.quote,
    entries: input.entries,
    note: noteForEvidence,
    appearances: input.appearances,
    gapDays: input.gapDays,
    threadType: input.threadType,
    missingTranscript: input.missingTranscript,
    feedbackSummary,
    scores: buildResurfacingScores({
      quote: input.quote,
      appearances: input.appearances ?? 2,
      gapDays: input.gapDays,
      threadType: input.threadType,
    }),
  };

  const evidence = buildResurfacingEvidence(buildInput);
  const suppressionReasons = [...evidence.suppressionReasons];
  let show = true;
  let safeDisplayMode: ResurfacingSafeDisplayMode = "normal";

  if (!hasResurfacingEvidenceAnchors(evidence)) {
    show = false;
    suppressionReasons.push("no_concrete_evidence");
  }

  const missedSoftRestore = evidence.priorUserRejection === 12 ? 12 : 0;
  const acceptanceRestore =
    evidence.priorUserAcceptance > 0
      ? Math.min(10, Math.round(evidence.priorUserAcceptance * 0.45))
      : 0;
  const effectiveConfidence =
    evidence.finalConfidence + missedSoftRestore + acceptanceRestore;

  if (effectiveConfidence < MIN_GATE_CONFIDENCE) {
    show = false;
    suppressionReasons.push("confidence_below_threshold");
  }

  const minEvidenceScore =
    MIN_GATE_EVIDENCE_SCORE + Math.min(feedbackSummary.specificityThresholdBoost, 24);
  if (evidence.evidenceScore < minEvidenceScore) {
    show = false;
    suppressionReasons.push("evidence_score_below_threshold");
  }

  const specificityBoost = Math.max(
    feedbackSummary.specificityThresholdBoost,
    getSpecificityThresholdBoost(),
  );
  if (specificityBoost >= 6 && effectiveConfidence < 68) {
    show = false;
    suppressionReasons.push("too_vague_threshold");
  }

  if (
    isStaleWithoutReinforcement(evidence.stalenessDays, evidence.priorUserAcceptance)
  ) {
    show = false;
    suppressionReasons.push("stale_without_reinforcement");
  }

  if (evidence.cooldownStatus === "cooldown" || evidence.cooldownStatus === "retired") {
    show = false;
    suppressionReasons.push(`cooldown_${evidence.cooldownStatus}`);
  }

  if (evidence.priorUserRejection >= 35) {
    show = false;
    suppressionReasons.push("not_me_suppressed");
  }

  if (evidence.cooldownStatus === "fatigued" && evidence.evidenceScore < 45) {
    show = false;
    suppressionReasons.push("fatigued_weak_evidence");
  }

  const ambiguityPolicy = applyAmbiguityFailsafePolicy({
    evidence,
    missingTranscript: input.missingTranscript,
    quoteLength: quote.length,
  });

  if (ambiguityPolicy.suppress) {
    show = false;
    suppressionReasons.push(...ambiguityPolicy.reasons);
  }

  if (evidence.sarcasmSignal) {
    show = false;
    suppressionReasons.push("sarcasm_regex_fail_safe");
  }

  if (evidence.contradictionSignal) {
    safeDisplayMode = "change";
  } else if (ambiguityPolicy.forceCautious || evidence.cautiousWordingRequired) {
    safeDisplayMode = "cautious";
  }

  if (show && safeDisplayMode === "cautious" && isUncertaintyBudgetExceeded()) {
    show = false;
    suppressionReasons.push("uncertainty_budget_exceeded");
  }

  if (!show) {
    safeDisplayMode = "suppressed";
    for (const reason of suppressionReasons) {
      recordSuppressionMetric(reason);
    }
  }

  const cautious = safeDisplayMode === "cautious" || safeDisplayMode === "change";
  const whyLine = formatWhySurfacedFromEvidence(evidence, cautious);
  const whySurfacedLines = whyLine ? [whyLine] : [];

  let callbackText = input.displayText ?? input.quote;
  callbackText = sanitizeResurfacingCopyForAmbiguity(callbackText, cautious);

  if (!passesOverconfidentCopyGate(callbackText, cautious)) {
    show = false;
    suppressionReasons.push("overconfident_copy_blocked");
    safeDisplayMode = "suppressed";
  }

  if (show && cautious) {
    recordCautiousCallbackShown();
  }

  const sourceEntryIds =
    input.sourceEntryIds ??
    (input.note?.entryId
      ? [input.note.entryId, input.note.pastEntryId].filter((id): id is string => Boolean(id))
      : []);

  return {
    show,
    safeDisplayMode,
    callbackText,
    whySurfacedLines,
    evidence,
    suppressionReasons: [...new Set(suppressionReasons)],
    feedbackActions: CANONICAL_FEEDBACK_ACTIONS,
    finalConfidence: evidence.finalConfidence,
    sourceEntryIds,
    phraseKey,
  };
}

export function runCanonicalPipelineForMemoryNote(
  note: MemoryNote,
  entries: JournalEntry[],
): CanonicalResurfacingResult {
  const quote =
    note.currentQuote?.trim() || note.pastQuote?.trim() || note.text.trim();
  return runCanonicalResurfacingPipeline({
    quote,
    note,
    entries,
    displayText: note.text,
    sourceEntryIds: [note.entryId, note.pastEntryId].filter((id): id is string => Boolean(id)),
  });
}

export function runCanonicalPipelineForContinuity(input: {
  quote: string;
  appearances: number;
  gapDays?: number;
  threadType?: ReturnThread["type"];
  entries?: JournalEntry[];
  relatedEntryIds?: string[];
}): CanonicalResurfacingResult {
  const gated = gateContinuityQuote(input.quote) ?? input.quote;
  return runCanonicalResurfacingPipeline({
    quote: gated,
    appearances: input.appearances,
    gapDays: input.gapDays,
    threadType: input.threadType,
    entries: input.entries,
    displayText: gated,
    sourceEntryIds: input.relatedEntryIds,
  });
}

export function pickDisplayReadyCallbacks(
  candidates: CanonicalResurfacingInput[],
): CanonicalResurfacingResult[] {
  return candidates
    .map((c) => runCanonicalResurfacingPipeline(c))
    .filter((r) => r.show)
    .sort((a, b) => b.finalConfidence - a.finalConfidence);
}
