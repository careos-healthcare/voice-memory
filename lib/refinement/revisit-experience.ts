import {
  trackRememberedLaterDelayedRevisit,
  trackRememberedLaterDelayedReflection,
} from "@/lib/social-proof/remembered-later";
import { maybeTrackRevisitAfterShare } from "@/lib/sharing/share-observation";
import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import {
  entryInteractionSummary,
  recordCallbackSurfaced,
} from "@/lib/callback-interaction-signals";
import { trackLocalEvent } from "@/lib/local-analytics";
import { entryChangeMomentsNotes } from "@/lib/memory/change-moments";
import { entryMemoryNotes } from "@/lib/patterns/memory-notes";
import { getBookmarkForEntry } from "@/lib/reflection-bookmarks";
import {
  entryRevisitRewardCandidates,
  isTopicRecurrenceCopy,
  pickEntryRevisitContrast,
  pickEntryRevisitRewardLine,
  REVISIT_REWARD_COPY,
} from "@/lib/refinement/knows-me-moments";
import {
  REVISIT_REWARD_SUPPRESS_ID,
  REVISIT_REWARD_SUPPRESS_TEXT,
} from "@/lib/refinement/callback-suppression";
import { SCORE_REVISIT_REWARD } from "@/lib/refinement/score-thresholds";
import { scoreMemoryHierarchy } from "@/lib/refinement/memory-hierarchy";
import {
  markRevisitBoost,
} from "@/lib/refinement/emotional-timing";
import {
  pickReopenFirstLine,
  pickStrongestReopenMoment,
  rankReopenPayoffNotes,
  resolveReopenFollowupDelayMs,
  type ReopenPayoffScore,
} from "@/lib/refinement/reopen-payoff";
import { calibrateRevisitExperience } from "@/lib/refinement/silence-calibration";
import { pickLivingResurfacingForEntry } from "@/lib/memory/living-resurfacing";
import { pickEmotionalChapterForEntry } from "@/lib/memory/emotional-chapters";
import { pickVoiceIdentityForEntry } from "@/lib/memory/voice-identity";
import {
  markMoatRevisitAudioReplayed,
  markMoatRevisitThenVsNow,
  trackOldEntryMoatRevisit,
} from "@/lib/retention/moat-metrics";
import { CONTINUATION_COPY } from "@/lib/conversation/continuation-loops";
import { recordRevisitContext } from "@/lib/sync/cross-device-continuity";
import {
  rememberNoteContext,
  trackEntryRevisited as trackRetentionEntryRevisited,
} from "@/lib/retention/retention-loops";
import type { FollowupPrompt } from "@/types/followup-prompt";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

const REVISIT_NAV_KEY = "voicememory_revisit_nav";
const REVISIT_REWARD_MIN = SCORE_REVISIT_REWARD;

export const REVISIT_QUIET_COPY_EXAMPLES = [
  REVISIT_REWARD_COPY.soundDifferentNow,
  REVISIT_REWARD_COPY.notNamedYet,
  REVISIT_REWARD_COPY.usedToTakeSpace,
  REVISIT_REWARD_COPY.beforeThingsChanged,
  REVISIT_REWARD_COPY.soundFurtherAway,
] as const;

export type RevisitQuietCopy = (typeof REVISIT_QUIET_COPY_EXAMPLES)[number];

export type RevisitSource =
  | "prior_view"
  | "memory_note"
  | "resurfacing"
  | "revisitation"
  | "bookmark"
  | "thread"
  | "timeline"
  | "memory"
  | "monthly";

export interface RevisitContext {
  isRevisit: boolean;
  sources: RevisitSource[];
}

export interface RevisitExperiencePresentation {
  isRevisit: boolean;
  sources: RevisitSource[];
  /** Immediate human line — “you sound different”. */
  revisitReward: MemoryNote | null;
  /** Quote-backed before/after when contrast is obvious. */
  thenVsNow: MemoryNote | null;
  /** Old entry whose meaning shifted as the archive grew. */
  livingResurfacing: MemoryNote | null;
  /** How you sound on this thread — transcript pacing, not clinical analysis. */
  voiceIdentity: MemoryNote | null;
  /** When this reflection belonged — before/during/after, without charts. */
  emotionalChapter: MemoryNote | null;
  followupPrompt: FollowupPrompt | null;
  reopenPayoffScore: ReopenPayoffScore | null;
  followupDelayMs: number;
}

interface RevisitNavigationHint {
  entryId: string;
  source: RevisitSource;
  at: number;
}


function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function hasContrastEvidence(note: MemoryNote): boolean {
  return Boolean(note.pastQuote?.trim() && note.currentQuote?.trim());
}

function isDuplicateNote(a: MemoryNote, b: MemoryNote | null | undefined): boolean {
  if (!b) return false;
  return a.id === b.id || a.text === b.text;
}

function realizationNote(text: string, entryId: string, confidence = 68): MemoryNote {
  return {
    id: `revisit-reward-${entryId}`,
    text,
    category: "returned",
    confidence,
    entryId,
  };
}

function isWeakForRevisit(note: MemoryNote): boolean {
  if (REVISIT_REWARD_SUPPRESS_ID.test(note.id)) return true;
  if (REVISIT_REWARD_SUPPRESS_TEXT.test(note.text)) return true;
  if (isTopicRecurrenceCopy(note.text)) return true;
  return false;
}

function isStrongForRevisit(note: MemoryNote, entries: JournalEntry[]): boolean {
  if (isWeakForRevisit(note)) return false;
  return scoreMemoryHierarchy(note, entries).total >= REVISIT_REWARD_MIN;
}

function gatherContrastExtras(
  allEntries: JournalEntry[],
  entryId: string,
): MemoryNote[] {
  const notes = entryMemoryNotes(allEntries, entryId);
  const changeMoments = entryChangeMomentsNotes(allEntries, entryId, 2);

  const pool = [...notes.thenVsNow, ...changeMoments]
    .filter(Boolean)
    .filter((note) => hasContrastEvidence(note as MemoryNote))
    .filter((note) => isStrongForRevisit(note as MemoryNote, allEntries)) as MemoryNote[];

  return rankReopenPayoffNotes(pool, allEntries);
}

function resolveRevisitRewardLine(
  allEntries: JournalEntry[],
  entryId: string,
  thenVsNow: MemoryNote | null,
  bestLine: MemoryNote | null,
  payoffScore: ReopenPayoffScore | null,
): MemoryNote | null {
  const anchorNote = thenVsNow ?? bestLine;
  const firstLine = pickReopenFirstLine(anchorNote, allEntries, payoffScore);

  if (thenVsNow) {
    return realizationNote(firstLine, entryId, thenVsNow.confidence);
  }

  if (bestLine && isStrongForRevisit(bestLine, allEntries)) {
    return realizationNote(firstLine, entryId, bestLine.confidence);
  }

  const quietCopy = pickReopenFirstLine(null, allEntries, payoffScore);
  return realizationNote(quietCopy, entryId);
}

function buildRevisitFollowupPrompt(
  reward: MemoryNote | null,
  contrast: MemoryNote | null,
): FollowupPrompt | null {
  if (!reward?.text.trim() && !contrast?.pastQuote?.trim()) return null;

  if (contrast?.pastQuote?.trim() && contrast?.currentQuote?.trim()) {
    return {
      id: `followup-revisit-${contrast.id}`,
      text: CONTINUATION_COPY.sayBackToSelf,
      source: "revisit_contrast",
      noteId: contrast.id,
      noteText: reward?.text ?? contrast.text,
      strength: Math.max(contrast.confidence, reward?.confidence ?? 0),
    };
  }

  if (!reward?.text.trim()) return null;

  return {
    id: `followup-revisit-${reward.id}`,
    text: CONTINUATION_COPY.moreToSay,
    source: "revisitation",
    noteId: reward.id,
    noteText: reward.text,
    strength: reward.confidence,
  };
}

/** Then-vs-now for display — quotes only, no headline paragraph. */
export function revisitThenVsNowDisplayNote(note: MemoryNote): MemoryNote {
  return { ...note, text: "" };
}

/** Mark navigation toward an entry as a memory-driven revisit. */
export function markRevisitNavigation(entryId: string, source: RevisitSource): void {
  if (!isBrowser()) return;
  const payload: RevisitNavigationHint = {
    entryId,
    source,
    at: Date.now(),
  };
  sessionStorage.setItem(REVISIT_NAV_KEY, JSON.stringify(payload));
  recordRevisitContext(entryId, source);
}

/** Read and clear a pending revisit navigation hint for this entry. */
export function consumeRevisitNavigation(entryId: string): RevisitSource | null {
  if (!isBrowser()) return null;
  try {
    const raw = sessionStorage.getItem(REVISIT_NAV_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as RevisitNavigationHint;
    sessionStorage.removeItem(REVISIT_NAV_KEY);
    if (parsed.entryId !== entryId) return null;
    if (Date.now() - parsed.at > 1000 * 60 * 30) return null;
    return parsed.source;
  } catch {
    return null;
  }
}

export function revisitSourceFromNote(note: MemoryNote): RevisitSource {
  if (note.id.startsWith("resurface-")) return "resurfacing";
  if (note.id.startsWith("revisit-")) return "revisitation";
  if (note.id.startsWith("fam-resurface-")) return "memory";
  if (note.id.startsWith("tvn-")) return "memory_note";
  return "memory_note";
}

export function revisitSourceFromPath(pathname: string): RevisitSource | null {
  if (pathname.startsWith("/timeline")) return "timeline";
  if (pathname.startsWith("/memory")) return "memory";
  if (pathname.startsWith("/monthly")) return "monthly";
  if (pathname.startsWith("/threads")) return "thread";
  if (pathname.startsWith("/bookmarks")) return "bookmark";
  return null;
}

/** Detect whether this entry page load is emotionally a revisit. */
export function detectRevisitContext(entryId: string): RevisitContext {
  const sources: RevisitSource[] = [];
  const nav = consumeRevisitNavigation(entryId);
  if (nav) sources.push(nav);
  if (getBookmarkForEntry(entryId)) sources.push("bookmark");
  const summary = entryInteractionSummary(entryId);
  if ((summary?.viewCount ?? 0) > 1) sources.push("prior_view");

  return {
    isRevisit: sources.length > 0,
    sources: [...new Set(sources)],
  };
}

/** Revisit entry presentation — reward line, contrast quotes, follow-up. */
export function buildRevisitExperience(
  allEntries: JournalEntry[],
  entryId: string,
  _limits: {
    changeMoments: number;
    familiarityResurfacing: number;
    resurfacing: number;
  },
): RevisitExperiencePresentation {
  const context = detectRevisitContext(entryId);

  if (!context.isRevisit) {
    return {
      isRevisit: false,
      sources: [],
      revisitReward: null,
      thenVsNow: null,
      livingResurfacing: null,
      voiceIdentity: null,
      emotionalChapter: null,
      followupPrompt: null,
      reopenPayoffScore: null,
      followupDelayMs: 0,
    };
  }

  markRevisitBoost();

  const knowsMeCandidates = entryRevisitRewardCandidates(allEntries, entryId).filter((note) =>
    isStrongForRevisit(note, allEntries),
  );
  const contrastExtras = gatherContrastExtras(allEntries, entryId);

  const strongest = pickStrongestReopenMoment(
    [...knowsMeCandidates, ...contrastExtras],
    allEntries,
    entryId,
  );
  const payoffScore = strongest.score;

  const thenVsNow =
    strongest.moment?.pastQuote?.trim() && strongest.moment.currentQuote?.trim()
      ? strongest.moment
      : pickEntryRevisitContrast(knowsMeCandidates, contrastExtras, [], allEntries);

  const bestLine = pickEntryRevisitRewardLine(
    knowsMeCandidates,
    [thenVsNow, strongest.moment],
    allEntries,
  );
  const revisitReward = resolveRevisitRewardLine(
    allEntries,
    entryId,
    thenVsNow,
    bestLine,
    payoffScore,
  );
  const livingResurfacing = pickLivingResurfacingForEntry(allEntries, entryId);
  const voiceIdentity = pickVoiceIdentityForEntry(allEntries, entryId);
  const emotionalChapter = pickEmotionalChapterForEntry(allEntries, entryId);
  const followupPrompt = buildRevisitFollowupPrompt(revisitReward, thenVsNow);
  const followupDelayMs = resolveReopenFollowupDelayMs(payoffScore);

  const calibrated = calibrateRevisitExperience(
    {
      isRevisit: true,
      sources: context.sources,
      revisitReward,
      thenVsNow,
      livingResurfacing,
      voiceIdentity,
      emotionalChapter,
      followupPrompt,
    },
    allEntries,
  );

  for (const note of [calibrated.revisitReward, calibrated.thenVsNow].filter(Boolean) as MemoryNote[]) {
    recordCallbackSurfaced(note.id, "entry");
    const contextEntryId = note.entryId ?? note.pastEntryId ?? entryId;
    rememberNoteContext(contextEntryId, note.id, note.text);
  }

  const resolvedLivingResurfacing =
    calibrated.livingResurfacing &&
    calibrated.livingResurfacing.text !== calibrated.revisitReward?.text
      ? calibrated.livingResurfacing
      : null;

  const resolvedVoiceIdentity =
    calibrated.voiceIdentity &&
    calibrated.voiceIdentity.text !== calibrated.revisitReward?.text &&
    calibrated.voiceIdentity.text !== resolvedLivingResurfacing?.text
      ? calibrated.voiceIdentity
      : null;

  const resolvedEmotionalChapter =
    calibrated.emotionalChapter &&
    calibrated.emotionalChapter.text !== calibrated.revisitReward?.text &&
    calibrated.emotionalChapter.text !== resolvedLivingResurfacing?.text &&
    calibrated.emotionalChapter.text !== resolvedVoiceIdentity?.text
      ? calibrated.emotionalChapter
      : null;

  return {
    ...calibrated,
    livingResurfacing: resolvedLivingResurfacing,
    voiceIdentity: resolvedVoiceIdentity,
    emotionalChapter: resolvedEmotionalChapter,
    reopenPayoffScore: payoffScore,
    followupDelayMs,
  };
}

export function trackRevisitOpened(entryId: string, sources: RevisitSource[]): void {
  trackLocalEvent("revisit_opened", {
    entryId,
    sources: sources.join(","),
  });
  trackRetentionEntryRevisited(entryId, sources);
  trackOldEntryMoatRevisit(entryId, sources);
  maybeTrackRevisitAfterShare(entryId);

  if (isBrowser()) {
    try {
      const raw = localStorage.getItem("voicememory_revisit_last_open");
      const prior = raw ? (JSON.parse(raw) as { entryId: string; at: string }) : null;
      localStorage.setItem(
        "voicememory_revisit_last_open",
        JSON.stringify({ entryId, at: new Date().toISOString() }),
      );
      if (prior?.at) {
        const gap = daysBetweenKeys(toDayKey(prior.at), toDayKey(new Date().toISOString()));
        if (gap >= 2) {
          trackRememberedLaterDelayedRevisit(prior.entryId ?? entryId, entryId);
        }
      }
    } catch {
      // ignore storage errors
    }
  }
}

export function trackRevisitRewardSeen(entryId: string, noteId: string): void {
  trackLocalEvent("revisit_reward_seen", { entryId, noteId });
}

export function trackRevisitThenNowSeen(entryId: string, noteId: string): void {
  trackLocalEvent("revisit_then_now_seen", { entryId, noteId });
  markMoatRevisitThenVsNow(entryId);
}

export function trackRevisitRewardFollowup(entryId: string, promptId: string): void {
  trackLocalEvent("revisit_reward_followup", { entryId, promptId });
}

export function trackRevisitRewardBookmark(entryId: string, bookmarkType: string): void {
  trackLocalEvent("revisit_reward_bookmark", { entryId, bookmarkType });
}

export function trackRevisitAudioPlayed(entryId: string, clip: "then" | "now"): void {
  trackLocalEvent("revisit_audio_played", { entryId, clip });
  markMoatRevisitAudioReplayed(entryId);
}

export function trackRevisitFollowupStarted(entryId: string, promptId: string): void {
  trackLocalEvent("revisit_followup_started", { entryId, promptId });
  trackRevisitRewardFollowup(entryId, promptId);
  trackRememberedLaterDelayedReflection(promptId, entryId);
}
