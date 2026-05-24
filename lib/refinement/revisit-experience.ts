import { recordCallbackSurfaced } from "@/lib/callback-interaction-signals";
import { entryInteractionSummary } from "@/lib/callback-interaction-signals";
import { trackLocalEvent } from "@/lib/local-analytics";
import { entryChangeMomentsNotes } from "@/lib/memory/change-moments";
import { entryMemoryNotes } from "@/lib/patterns/memory-notes";
import { getBookmarkForEntry } from "@/lib/reflection-bookmarks";
import {
  entryRevisitRewardCandidates,
  pickEntryRevisitContrast,
  pickEntryRevisitRewardLine,
  REVISIT_REWARD_COPY,
} from "@/lib/refinement/knows-me-moments";
import { scoreMemoryHierarchy } from "@/lib/refinement/memory-hierarchy";
import {
  markRevisitBoost,
} from "@/lib/refinement/emotional-timing";
import { calibrateRevisitExperience } from "@/lib/refinement/silence-calibration";
import {
  rememberNoteContext,
  trackEntryRevisited as trackRetentionEntryRevisited,
} from "@/lib/retention/retention-loops";
import type { FollowupPrompt } from "@/types/followup-prompt";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

const REVISIT_NAV_KEY = "voicememory_revisit_nav";
const REVISIT_REWARD_MIN = 56;

export const REVISIT_QUIET_COPY_EXAMPLES = [
  REVISIT_REWARD_COPY.beforeThingsChanged,
  REVISIT_REWARD_COPY.soundCalmerNow,
  REVISIT_REWARD_COPY.notNamedYet,
  REVISIT_REWARD_COPY.usedToTakeSpace,
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
  /** Immediate text-only line — why this entry was worth reopening. */
  revisitReward: MemoryNote | null;
  /** Quote-backed before/after contrast when evidence exists. */
  thenVsNow: MemoryNote | null;
  followupPrompt: FollowupPrompt | null;
}

interface RevisitNavigationHint {
  entryId: string;
  source: RevisitSource;
  at: number;
}

const REVISIT_SUPPRESSED_ID =
  /^rhythm-|^time-|^continuity-thread-|^continuity-recurring-|^archive-|^continuity-depth-|^resurface-topic-|^resurface-entity-|^resurface-phrase-|^resurface-person-|^resurface-loop-|^familiarity-|^fam-resurface-similar|^revisit-loop-|^continuity-callback-/;

const REVISIT_SUPPRESSED_TEXT =
  /\b(you came back to the same place|you spoke about this the same way|older reflections are starting|starting to mean something|kept coming back to a few things|tends to return|weekly rhythm|gap between these entries|you left off here|came up again|showed up again|keeps showing up|same theme|same topic|returned to this|spoke about this again)\b/i;

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

function realizationNote(text: string, entryId: string, confidence = 64): MemoryNote {
  return {
    id: `revisit-reward-${entryId}`,
    text,
    category: "returned",
    confidence,
    entryId,
  };
}

function isWeakForRevisit(note: MemoryNote): boolean {
  if (REVISIT_SUPPRESSED_ID.test(note.id)) return true;
  if (REVISIT_SUPPRESSED_TEXT.test(note.text)) return true;
  return false;
}

function isStrongForRevisit(note: MemoryNote, entries: JournalEntry[]): boolean {
  if (isWeakForRevisit(note)) return false;
  return scoreMemoryHierarchy(note, entries).total >= REVISIT_REWARD_MIN;
}

function canonicalCopyForNote(note: MemoryNote): RevisitQuietCopy {
  if (note.id.startsWith("revisit-before-quiet") || /before things (got quieter|changed)/i.test(note.text)) {
    return REVISIT_REWARD_COPY.beforeThingsChanged;
  }
  if (note.id.startsWith("change-charged") || /more pressure before|take up more space|felt heavier/i.test(note.text)) {
    return REVISIT_REWARD_COPY.usedToTakeSpace;
  }
  if (note.id.startsWith("change-hedge") || note.id.startsWith("change-direct") || /not named|named directly/i.test(note.text)) {
    return REVISIT_REWARD_COPY.notNamedYet;
  }
  if (note.id.startsWith("revisit-diff") || /sound calmer|more settled|quieter now/i.test(note.text)) {
    return REVISIT_REWARD_COPY.soundCalmerNow;
  }
  if (/calmer|quieter|settled/i.test(note.text)) {
    return REVISIT_REWARD_COPY.soundCalmerNow;
  }
  if (/named|directly|not sure|vague/i.test(note.text)) {
    return REVISIT_REWARD_COPY.notNamedYet;
  }
  if (/heavier|pressure|space|weight/i.test(note.text)) {
    return REVISIT_REWARD_COPY.usedToTakeSpace;
  }
  return REVISIT_REWARD_COPY.beforeThingsChanged;
}

/** Text-only reward line — never carries quote blocks. */
function toRewardLine(note: MemoryNote | null, entryId: string, fallback: RevisitQuietCopy): MemoryNote {
  const text = note ? canonicalCopyForNote(note) : fallback;
  return realizationNote(text, entryId, note?.confidence ?? 64);
}

function gatherContrastExtras(
  allEntries: JournalEntry[],
  entryId: string,
): MemoryNote[] {
  const notes = entryMemoryNotes(allEntries, entryId);
  const changeMoments = entryChangeMomentsNotes(allEntries, entryId, 2);

  return [...notes.thenVsNow, notes.whatChanged, ...changeMoments]
    .filter(Boolean)
    .filter((note) => hasContrastEvidence(note as MemoryNote))
    .filter((note) => isStrongForRevisit(note as MemoryNote, allEntries)) as MemoryNote[];
}

function pickRevisitQuietCopy(allEntries: JournalEntry[], entryId: string): RevisitQuietCopy {
  const entry = allEntries.find((row) => row.id === entryId);
  if (!entry) return REVISIT_REWARD_COPY.beforeThingsChanged;

  const prior = allEntries.filter(
    (row) => new Date(row.createdAt).getTime() < new Date(entry.createdAt).getTime(),
  );
  const themes = new Set(entry.reflection.recurringThemes.map((t) => t.toLowerCase()));
  const priorSameTheme = prior.filter((row) =>
    row.reflection.recurringThemes.some((t) => themes.has(t.toLowerCase())),
  );

  const directNow = /\b(named|decided|clearly|for sure|directly)\b/i.test(entry.transcript);
  const hedgedBefore = priorSameTheme.some((row) =>
    /\b(maybe|sort of|kind of|not sure|vague)\b/i.test(row.transcript),
  );
  if (!directNow && hedgedBefore) {
    return REVISIT_REWARD_COPY.notNamedYet;
  }

  const intenseBefore = priorSameTheme.some((row) => row.reflection.emotionalIntensity >= 6);
  if (intenseBefore && entry.reflection.emotionalIntensity <= 4.5) {
    return REVISIT_REWARD_COPY.soundCalmerNow;
  }

  if (priorSameTheme.length >= 2) {
    const moodShift =
      priorSameTheme[priorSameTheme.length - 1].reflection.mood !== entry.reflection.mood;
    const intensityDelta = Math.abs(
      entry.reflection.emotionalIntensity -
        priorSameTheme[priorSameTheme.length - 1].reflection.emotionalIntensity,
    );
    if (moodShift || intensityDelta >= 1.5) {
      return REVISIT_REWARD_COPY.beforeThingsChanged;
    }
  }

  const peak = priorSameTheme.reduce(
    (best, row) =>
      row.reflection.emotionalIntensity > best ? row.reflection.emotionalIntensity : best,
    0,
  );
  if (peak >= 6.5 && entry.reflection.emotionalIntensity <= peak - 1.5) {
    return REVISIT_REWARD_COPY.usedToTakeSpace;
  }

  return REVISIT_REWARD_COPY.beforeThingsChanged;
}

function buildRevisitFollowupPrompt(
  reward: MemoryNote | null,
  contrast: MemoryNote | null,
): FollowupPrompt | null {
  if (contrast?.pastQuote?.trim() && contrast?.currentQuote?.trim()) {
    return {
      id: `followup-revisit-${contrast.id}`,
      text: "What changed?",
      source: "then_vs_now",
      noteId: contrast.id,
      noteText: contrast.text,
      strength: contrast.confidence,
    };
  }

  if (!reward) return null;

  return {
    id: `followup-revisit-${reward.id}`,
    text: "What feels different now?",
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

/** Revisit entry presentation — immediate reward, contrast, audio, follow-up. */
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
      followupPrompt: null,
    };
  }

  markRevisitBoost();

  const knowsMeCandidates = entryRevisitRewardCandidates(allEntries, entryId).filter((note) =>
    isStrongForRevisit(note, allEntries),
  );
  const contrastExtras = gatherContrastExtras(allEntries, entryId);

  const thenVsNow = pickEntryRevisitContrast(knowsMeCandidates, contrastExtras, []);

  const bestLine = pickEntryRevisitRewardLine(knowsMeCandidates, [thenVsNow]);
  const fallbackCopy = pickRevisitQuietCopy(allEntries, entryId);
  let revisitReward = toRewardLine(bestLine, entryId, fallbackCopy);

  if (thenVsNow && isDuplicateNote(revisitReward, thenVsNow)) {
    revisitReward = realizationNote(fallbackCopy, entryId);
  }

  const calibrated = calibrateRevisitExperience(
    {
      isRevisit: true,
      sources: context.sources,
      revisitReward,
      thenVsNow: thenVsNow && !isDuplicateNote(thenVsNow, revisitReward) ? thenVsNow : null,
      followupPrompt: null,
    },
    allEntries,
  );

  for (const note of [calibrated.revisitReward, calibrated.thenVsNow].filter(Boolean) as MemoryNote[]) {
    recordCallbackSurfaced(note.id, "entry");
    const contextEntryId = note.entryId ?? note.pastEntryId ?? entryId;
    rememberNoteContext(contextEntryId, note.id, note.text);
  }

  return {
    ...calibrated,
    followupPrompt: buildRevisitFollowupPrompt(calibrated.revisitReward, calibrated.thenVsNow),
  };
}

export function trackRevisitOpened(entryId: string, sources: RevisitSource[]): void {
  trackLocalEvent("revisit_opened", {
    entryId,
    sources: sources.join(","),
  });
  trackRetentionEntryRevisited(entryId, sources);
}

export function trackRevisitRewardSeen(entryId: string, noteId: string): void {
  trackLocalEvent("revisit_reward_seen", { entryId, noteId });
}

export function trackRevisitThenNowSeen(entryId: string, noteId: string): void {
  trackLocalEvent("revisit_then_now_seen", { entryId, noteId });
}

export function trackRevisitRewardFollowup(entryId: string, promptId: string): void {
  trackLocalEvent("revisit_reward_followup", { entryId, promptId });
}

export function trackRevisitRewardBookmark(entryId: string, bookmarkType: string): void {
  trackLocalEvent("revisit_reward_bookmark", { entryId, bookmarkType });
}

export function trackRevisitAudioPlayed(entryId: string, clip: "then" | "now"): void {
  trackLocalEvent("revisit_audio_played", { entryId, clip });
}

export function trackRevisitFollowupStarted(entryId: string, promptId: string): void {
  trackLocalEvent("revisit_followup_started", { entryId, promptId });
  trackRevisitRewardFollowup(entryId, promptId);
}
