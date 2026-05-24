import {
  averageEntryDwellMs,
  readCallbackRetention,
} from "@/lib/callback-interaction-signals";
import { readRetentionLoopEvents, type RetentionLoopEvent } from "@/lib/retention/retention-loops";
import { computeCallbackPauseAnalysis } from "@/lib/retention/pause-moments";
import type {
  CallbackReviewItem,
  CallbackReviewLabel,
  CallbackSurvivalAnalysis,
  RewriteCandidateFlag,
} from "@/types/callback-quality-review";

const POSITIVE_LABELS: CallbackReviewLabel[] = [
  "landed_emotionally",
  "memorable",
  "emotionally_precise",
  "high_emotional_residue",
  "comforting",
  "worth_revisiting",
];

const NEGATIVE_LABELS: CallbackReviewLabel[] = [
  "felt_generic",
  "too_analytical",
  "forgettable",
  "too_obvious",
  "cold",
  "invasive",
];

const HOURS_24 = 1000 * 60 * 60 * 24;

type ResidueInput = Pick<
  CallbackReviewItem,
  "signals" | "retention" | "continuedFollowup"
>;

type SurvivalInput = Pick<
  CallbackReviewItem,
  | "id"
  | "followupNoteId"
  | "signals"
  | "retention"
  | "continuedFollowup"
  | "sourceEntries"
>;

function noteKeysForCallback(item: SurvivalInput): string[] {
  return [
    item.id,
    item.followupNoteId,
    ...item.sourceEntries.map((entry) => entry.id),
  ].filter((value): value is string => Boolean(value));
}

function matchesNoteKeys(
  event: RetentionLoopEvent,
  callbackId: string,
  noteKeys: string[],
): boolean {
  if (event.noteId === callbackId || noteKeys.includes(event.noteId ?? "")) return true;
  if (event.sourceId === callbackId || noteKeys.includes(event.sourceId ?? "")) return true;
  return false;
}

function countLoopEvents(
  events: RetentionLoopEvent[],
  callbackId: string,
  noteKeys: string[],
  kinds: RetentionLoopEvent["kind"][],
): number {
  return events.filter(
    (event) => kinds.includes(event.kind) && matchesNoteKeys(event, callbackId, noteKeys),
  ).length;
}

function firstShownAt(callbackId: string): number | null {
  const surfaced = readCallbackRetention(callbackId)
    .filter((row) => row.outcome === "surfaced")
    .map((row) => new Date(row.at).getTime());
  if (surfaced.length === 0) return null;
  return Math.min(...surfaced);
}

function hasPostSurfaceEngagementWithin(
  callbackId: string,
  noteKeys: string[],
  loopEvents: RetentionLoopEvent[],
  hours: number,
): boolean {
  const anchor = firstShownAt(callbackId);
  if (anchor === null) return false;
  const windowEnd = anchor + hours * HOURS_24;

  const retentionHit = readCallbackRetention(callbackId).some((row) => {
    if (row.outcome === "surfaced" || row.outcome === "ignored") return false;
    const at = new Date(row.at).getTime();
    return at > anchor && at <= windowEnd;
  });
  if (retentionHit) return true;

  return loopEvents.some((event) => {
    if (!matchesNoteKeys(event, callbackId, noteKeys)) return false;
    const at = new Date(event.at).getTime();
    if (at <= anchor || at > windowEnd) return false;
    return [
      "resurfaced_memory_clicked",
      "old_entry_opened_from_note",
      "entry_revisited",
      "bookmark_created",
      "copied_memory_moment",
      "followup_recording_started",
      "followup_recording_completed",
      "returned_next_day",
      "returned_within_7_days",
    ].includes(event.kind);
  });
}

/** Per-callback survival fields — which lines linger after surfacing. */
export function computeCallbackSurvival(
  item: SurvivalInput,
  labels: CallbackReviewLabel[] = [],
  loopEvents: RetentionLoopEvent[] = readRetentionLoopEvents(),
): CallbackSurvivalAnalysis {
  const noteKeys = noteKeysForCallback(item);
  const entryIds = item.sourceEntries.map((entry) => entry.id);

  const callbackShownCount = item.retention.surfaced;
  const rereadCount = Math.max(item.retention.reread, item.signals.rereadCount);
  const revisitCount = Math.max(item.retention.revisit, item.signals.revisitCount);

  const oldEntryRevisitCount = Math.max(
    countLoopEvents(loopEvents, item.id, noteKeys, ["old_entry_opened_from_note"]),
    revisitCount,
  );

  const bookmarkAfterCallbackCount = Math.max(
    item.retention.bookmark,
    item.signals.bookmarked ? 1 : 0,
    countLoopEvents(loopEvents, item.id, noteKeys, ["bookmark_created"]),
  );

  const copiedMemoryMomentCount = Math.max(
    item.retention.copied,
    item.signals.memoryMomentCopied ? 1 : 0,
    countLoopEvents(loopEvents, item.id, noteKeys, ["copied_memory_moment"]),
  );

  const followUpStartCount = Math.max(
    item.retention.recording > 0 ? 1 : 0,
    countLoopEvents(loopEvents, item.id, noteKeys, ["followup_recording_started"]),
  );

  const followUpCompleteCount = Math.max(
    item.continuedFollowup ? 1 : 0,
    countLoopEvents(loopEvents, item.id, noteKeys, ["followup_recording_completed"]),
  );

  const dwellTimeAverageMs = averageEntryDwellMs(entryIds);

  const remembered24hManual = labels.includes("remembered_24h");
  const remembered72hManual = labels.includes("remembered_72h");

  const remembered24hFlag =
    remembered24hManual ||
    countLoopEvents(loopEvents, item.id, noteKeys, ["returned_next_day"]) > 0 ||
    hasPostSurfaceEngagementWithin(item.id, noteKeys, loopEvents, 24);

  const remembered72hFlag =
    remembered72hManual ||
    countLoopEvents(loopEvents, item.id, noteKeys, ["returned_within_7_days"]) > 0 ||
    hasPostSurfaceEngagementWithin(item.id, noteKeys, loopEvents, 72);

  const pauseScore = Math.min(100, Math.round(dwellTimeAverageMs / 45));
  const revisitScore = Math.min(
    100,
    rereadCount * 14 + oldEntryRevisitCount * 22 + revisitCount * 16,
  );
  const continuationScore = Math.min(
    100,
    followUpStartCount * 24 + followUpCompleteCount * 38,
  );

  let rememberedScore = 0;
  if (remembered24hFlag || remembered24hManual) rememberedScore += 42;
  if (remembered72hFlag || remembered72hManual) rememberedScore += 36;
  if (labels.includes("memorable")) rememberedScore += 12;
  if (labels.includes("high_emotional_residue")) rememberedScore += 14;
  if (labels.includes("forgettable")) rememberedScore -= 24;
  rememberedScore = Math.max(0, Math.min(100, rememberedScore));

  const emotionalSurvivalScore = Math.min(
    100,
    Math.round(
      pauseScore * 0.18 +
        revisitScore * 0.28 +
        continuationScore * 0.2 +
        rememberedScore * 0.24 +
        Math.min(18, bookmarkAfterCallbackCount * 9) +
        Math.min(16, copiedMemoryMomentCount * 10),
    ),
  );

  const lowSurvivalCutCandidate = isLowSurvivalCutCandidate(
    emotionalSurvivalScore,
    callbackShownCount,
    rereadCount,
    oldEntryRevisitCount,
    bookmarkAfterCallbackCount,
    copiedMemoryMomentCount,
    followUpCompleteCount,
    remembered24hFlag,
    remembered72hFlag,
    labels,
  );

  return {
    callbackShownCount,
    rereadCount,
    oldEntryRevisitCount,
    bookmarkAfterCallbackCount,
    copiedMemoryMomentCount,
    followUpStartCount,
    followUpCompleteCount,
    dwellTimeAverageMs,
    remembered24hFlag,
    remembered24hManual,
    remembered72hFlag,
    remembered72hManual,
    pauseScore,
    revisitScore,
    continuationScore,
    rememberedScore,
    emotionalSurvivalScore,
    lowSurvivalCutCandidate,
  };
}

export function isLowSurvivalCutCandidate(
  emotionalSurvivalScore: number,
  callbackShownCount: number,
  rereadCount: number,
  oldEntryRevisitCount: number,
  bookmarkAfterCallbackCount: number,
  copiedMemoryMomentCount: number,
  followUpCompleteCount: number,
  remembered24hFlag: boolean,
  remembered72hFlag: boolean,
  labels: CallbackReviewLabel[],
): boolean {
  if (labels.includes("forgettable")) return true;
  if (emotionalSurvivalScore < 22) return true;
  if (callbackShownCount >= 2 && emotionalSurvivalScore < 35) return true;

  const anySurvival =
    rereadCount > 0 ||
    oldEntryRevisitCount > 0 ||
    bookmarkAfterCallbackCount > 0 ||
    copiedMemoryMomentCount > 0 ||
    followUpCompleteCount > 0 ||
    remembered24hFlag ||
    remembered72hFlag;

  return callbackShownCount > 0 && !anySurvival && emotionalSurvivalScore < 40;
}

/** Engagement-weighted score — how much residue a line left behind. */
export function computeEmotionalResidueScore(
  item: ResidueInput,
  labels: CallbackReviewLabel[] = [],
): number {
  let score = 0;

  const rereads = Math.max(item.retention.reread, item.signals.rereadCount);
  const revisits = Math.max(item.retention.revisit, item.signals.revisitCount);

  score += Math.min(32, rereads * 10);
  score += Math.min(28, revisits * 12);
  if (item.retention.bookmark > 0 || item.signals.bookmarked) score += 20;
  if (item.retention.copied > 0 || item.signals.memoryMomentCopied) score += 22;
  if (item.continuedFollowup || item.retention.recording > 0) score += 24;
  score += Math.min(18, Math.round(item.signals.dwellMs / 4500));

  if (labels.includes("high_emotional_residue")) score += 25;
  if (labels.includes("landed_emotionally")) score += 14;
  if (labels.includes("memorable")) score += 12;
  if (labels.includes("forgettable")) score -= 22;
  if (labels.includes("felt_generic")) score -= 16;

  return Math.max(0, Math.round(score));
}

/** Combined tuning score — engagement + manual review + copy quality. */
export function computeQualityScore(
  item: Pick<
    CallbackReviewItem,
    | "signals"
    | "retention"
    | "continuedFollowup"
    | "rewriteFlags"
    | "confidence"
    | "emotionalWeight"
  >,
  labels: CallbackReviewLabel[],
  emotionalResidue: number,
): number {
  let score = emotionalResidue * 0.55;

  for (const label of labels) {
    if (POSITIVE_LABELS.includes(label)) score += 11;
    if (NEGATIVE_LABELS.includes(label)) score -= 13;
  }

  score -= item.rewriteFlags.length * 7;
  score += Math.min(12, item.confidence / 9);
  score += Math.min(8, item.emotionalWeight / 12);

  return Math.max(0, Math.round(score));
}

export function isCutCandidate(
  qualityScore: number,
  emotionalResidue: number,
  labels: CallbackReviewLabel[],
  rewriteFlags: RewriteCandidateFlag[],
): boolean {
  if (qualityScore < 22) return true;
  if (labels.includes("felt_generic") || labels.includes("forgettable")) return true;
  if (labels.includes("too_analytical") && emotionalResidue < 25) return true;
  if (rewriteFlags.length >= 2 && emotionalResidue < 18) return true;
  return false;
}

export function isDoubleDown(
  item: ResidueInput,
  emotionalResidue: number,
  labels: CallbackReviewLabel[],
): boolean {
  if (labels.includes("high_emotional_residue")) return true;
  if (emotionalResidue >= 58) return true;
  if (labels.includes("landed_emotionally") && labels.includes("memorable")) return true;

  const reread =
    item.retention.reread > 0 ||
    item.signals.rereadCount > 0 ||
    item.retention.revisit > 0 ||
    item.signals.revisitCount > 0;
  const action =
    item.signals.bookmarked ||
    item.signals.memoryMomentCopied ||
    item.continuedFollowup ||
    item.retention.recording > 0;

  return reread && action;
}

export type CallbackReviewFilter =
  | "all"
  | "cut_candidate"
  | "double_down"
  | "rewrite"
  | "landed_emotionally"
  | "felt_generic"
  | "too_analytical"
  | "memorable"
  | "reread"
  | "revisited"
  | "bookmarked"
  | "copied"
  | "followup_continued"
  | "survived_24h"
  | "survived_72h"
  | "caused_revisit"
  | "caused_followup"
  | "caused_bookmark"
  | "caused_copy"
  | "low_survival_cut"
  | "high_dwell_low_action"
  | "caused_audio_replay"
  | "caused_old_entry_revisit"
  | "top_pause";

export const CALLBACK_REVIEW_FILTERS: Array<{
  value: CallbackReviewFilter;
  label: string;
}> = [
  { value: "all", label: "All" },
  { value: "double_down", label: "Double down" },
  { value: "cut_candidate", label: "Cut candidate" },
  { value: "low_survival_cut", label: "Low survival cut" },
  { value: "survived_24h", label: "Survived 24h" },
  { value: "survived_72h", label: "Survived 72h" },
  { value: "caused_revisit", label: "Caused revisit" },
  { value: "caused_followup", label: "Caused follow-up" },
  { value: "caused_bookmark", label: "Caused bookmark" },
  { value: "caused_copy", label: "Caused copy" },
  { value: "high_dwell_low_action", label: "High dwell, low action" },
  { value: "caused_audio_replay", label: "Caused audio replay" },
  { value: "caused_old_entry_revisit", label: "Caused old-entry revisit" },
  { value: "top_pause", label: "Top pause" },
  { value: "rewrite", label: "Rewrite" },
  { value: "landed_emotionally", label: "Landed emotionally" },
  { value: "felt_generic", label: "Felt generic" },
  { value: "too_analytical", label: "Too analytical" },
  { value: "memorable", label: "Memorable" },
  { value: "reread", label: "Reread" },
  { value: "revisited", label: "Revisited" },
  { value: "bookmarked", label: "Bookmarked" },
  { value: "copied", label: "Copied" },
  { value: "followup_continued", label: "Follow-up continued" },
];

export function matchesCallbackFilter(
  item: CallbackReviewItem,
  filter: CallbackReviewFilter,
  labels: CallbackReviewLabel[],
): boolean {
  if (filter === "all") return true;
  if (filter === "cut_candidate") return item.cutCandidate;
  if (filter === "double_down") return item.doubleDown;
  if (filter === "rewrite") return item.rewriteFlags.length > 0;

  if (filter === "landed_emotionally") return labels.includes("landed_emotionally");
  if (filter === "felt_generic") return labels.includes("felt_generic");
  if (filter === "too_analytical") return labels.includes("too_analytical");
  if (filter === "memorable") return labels.includes("memorable");

  if (filter === "reread") {
    return item.retention.reread > 0 || item.signals.rereadCount > 0;
  }
  if (filter === "revisited") {
    return item.retention.revisit > 0 || item.signals.revisitCount > 0;
  }
  if (filter === "bookmarked") {
    return item.retention.bookmark > 0 || item.signals.bookmarked;
  }
  if (filter === "copied") {
    return item.retention.copied > 0 || item.signals.memoryMomentCopied;
  }
  if (filter === "followup_continued") {
    return item.continuedFollowup || item.retention.recording > 0;
  }

  const survival = item.survival;
  if (filter === "survived_24h") {
    return survival.remembered24hFlag || survival.remembered24hManual;
  }
  if (filter === "survived_72h") {
    return survival.remembered72hFlag || survival.remembered72hManual;
  }
  if (filter === "caused_revisit") {
    return survival.oldEntryRevisitCount > 0 || survival.rereadCount > 0;
  }
  if (filter === "caused_followup") {
    return survival.followUpStartCount > 0 || survival.followUpCompleteCount > 0;
  }
  if (filter === "caused_bookmark") {
    return survival.bookmarkAfterCallbackCount > 0;
  }
  if (filter === "caused_copy") {
    return survival.copiedMemoryMomentCount > 0;
  }
  if (filter === "low_survival_cut") {
    return survival.lowSurvivalCutCandidate;
  }

  const pause = item.pause;
  if (filter === "high_dwell_low_action") {
    return pause.highDwellLowAction;
  }
  if (filter === "caused_audio_replay") {
    return pause.causedAudioReplay;
  }
  if (filter === "caused_old_entry_revisit") {
    return pause.causedOldEntryRevisit;
  }
  if (filter === "top_pause") {
    return pause.pauseScore >= 55;
  }

  return true;
}

export type CallbackReviewItemDraft = Omit<
  CallbackReviewItem,
  | "manualLabels"
  | "emotionalResidueScore"
  | "qualityScore"
  | "cutCandidate"
  | "doubleDown"
  | "survival"
  | "pause"
>;

export function enrichCallbackReviewItem(
  item: CallbackReviewItemDraft,
  labels: CallbackReviewLabel[],
): CallbackReviewItem {
  const emotionalResidueScore = computeEmotionalResidueScore(item, labels);
  const qualityScore = computeQualityScore(item, labels, emotionalResidueScore);
  const survival = computeCallbackSurvival(item, labels);
  const noteKeys = noteKeysForCallback(item);
  const pause = computeCallbackPauseAnalysis(item.id, noteKeys);

  return {
    ...item,
    manualLabels: labels,
    emotionalResidueScore,
    qualityScore,
    cutCandidate: isCutCandidate(
      qualityScore,
      emotionalResidueScore,
      labels,
      item.rewriteFlags,
    ),
    doubleDown: isDoubleDown(item, emotionalResidueScore, labels),
    survival,
    pause,
  };
}

export function sortByPauseScore(items: CallbackReviewItem[]): CallbackReviewItem[] {
  return [...items].sort(
    (a, b) => b.pause.pauseScore - a.pause.pauseScore || b.pause.dwellAfterCallbackMs - a.pause.dwellAfterCallbackMs,
  );
}

export function sortByEmotionalSurvival(
  items: CallbackReviewItem[],
): CallbackReviewItem[] {
  return [...items].sort(
    (a, b) => b.survival.emotionalSurvivalScore - a.survival.emotionalSurvivalScore,
  );
}
