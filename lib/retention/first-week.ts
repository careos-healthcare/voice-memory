import { daysBetweenKeys, toDayKey, todayKey } from "@/lib/dates";
import { LAUNCH_EVENTS, hasLocalEvent, readLocalEvents } from "@/lib/local-analytics";
import { PHOTO_EVENTS } from "@/lib/local-analytics";
import { resolveSilenceIntelligence } from "@/lib/restraint/silence-intelligence";
import { readRetentionLoopEvents } from "@/lib/retention/retention-loops";
import { assessArchiveAttachment, isWithinFirstWeekOfArchive } from "@/lib/retention/archive-attachment-signals";
import { buildEmotionalTerritoriesReport } from "@/lib/territories/emotional-territories";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type {
  FirstWeekMilestone,
  FirstWeekMilestoneId,
  FirstWeekTimingRecommendation,
} from "@/types/first-week-retention";
import type { JournalEntry } from "@/types/journal";

const PROMPT_STATE_KEY = "voicememory_first_week_prompt_state";

interface PromptState {
  lastShownDay: string | null;
  ignoredCount: number;
  shownThisWeek: number;
  lastPromptId: string | null;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function defaultPromptState(): PromptState {
  return { lastShownDay: null, ignoredCount: 0, shownThisWeek: 0, lastPromptId: null };
}

function writePromptState(state: PromptState): void {
  if (!isBrowser()) return;
  localStorage.setItem(PROMPT_STATE_KEY, JSON.stringify(state));
}

export function readFirstWeekPromptState(): PromptState {
  if (!isBrowser()) return defaultPromptState();
  try {
    const raw = localStorage.getItem(PROMPT_STATE_KEY);
    if (!raw) return defaultPromptState();
    return { ...defaultPromptState(), ...(JSON.parse(raw) as PromptState) };
  } catch {
    return defaultPromptState();
  }
}

export function recordGentlePromptShown(promptId: string): void {
  const state = readFirstWeekPromptState();
  writePromptState({
    lastShownDay: todayKey(),
    ignoredCount: state.ignoredCount,
    shownThisWeek: state.shownThisWeek + 1,
    lastPromptId: promptId,
  });
}

export function recordGentlePromptIgnored(): void {
  const state = readFirstWeekPromptState();
  writePromptState({
    ...state,
    ignoredCount: state.ignoredCount + 1,
  });
}

export function recordGentlePromptEngaged(): void {
  const state = readFirstWeekPromptState();
  writePromptState({
    ...state,
    ignoredCount: 0,
  });
}

function firstReflectionAt(entries: JournalEntry[]): string | null {
  if (entries.length === 0) return null;
  const sorted = [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
  return sorted[0].createdAt;
}

export function firstWeekDayIndex(entries: JournalEntry[]): number | null {
  const anchor = firstReflectionAt(entries);
  if (!anchor) return null;
  return daysBetweenKeys(toDayKey(anchor), todayKey());
}

export function isWithinFirstWeek(entries: JournalEntry[] = getMemoryEligibleEntries()): boolean {
  const day = firstWeekDayIndex(entries);
  if (day === null) return true;
  return day <= 7;
}

function milestoneReached(
  id: FirstWeekMilestoneId,
  entries: JournalEntry[],
): { reachedAt: string | null; evidence: string } {
  const loops = readRetentionLoopEvents();
  const events = readLocalEvents();

  switch (id) {
    case "first_reflection":
      return entries.length >= 1
        ? { reachedAt: firstReflectionAt(entries), evidence: "At least one reflection saved" }
        : { reachedAt: null, evidence: "No reflections yet" };
    case "second_reflection":
      return entries.length >= 2
        ? {
            reachedAt: [...entries].sort(
              (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
            )[1].createdAt,
            evidence: "Two or more reflections",
          }
        : { reachedAt: null, evidence: "Only one reflection" };
    case "first_revisit": {
      const revisit = loops.find((e) => e.kind === "entry_revisited");
      const opened = events.find((e) => e.name === "revisit_opened");
      const at = revisit?.at ?? opened?.at ?? null;
      return at
        ? { reachedAt: at, evidence: "Entry reopened from memory or timeline" }
        : { reachedAt: null, evidence: "No revisit yet" };
    }
    case "first_emotional_callback": {
      const callbackEvent = events.find(
        (e) =>
          e.name.includes("callback") ||
          e.name === "primary_callback_seen" ||
          e.name === "memory_note_surfaced",
      );
      const at = callbackEvent?.at ?? null;
      return at
        ? { reachedAt: at, evidence: "Memory callback surfaced" }
        : { reachedAt: null, evidence: "No callback surfaced" };
    }
    case "first_photo_revisit": {
      const photo = events.find((e) => e.name === PHOTO_EVENTS.entryRevisited);
      return photo
        ? { reachedAt: photo.at, evidence: "Photo entry revisited" }
        : { reachedAt: null, evidence: "No photo revisit" };
    }
    case "first_territory_emergence": {
      const report = buildEmotionalTerritoriesReport(entries);
      const formed = report.territories.find((t) => t.entryIds.length >= 2);
      return formed
        ? { reachedAt: formed.latestAppearance, evidence: `${formed.label} forming` }
        : { reachedAt: null, evidence: "No territory cluster yet" };
    }
    default:
      return { reachedAt: null, evidence: "Unknown" };
  }
}

export function detectFirstWeekMilestones(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): FirstWeekMilestone[] {
  const ids: FirstWeekMilestoneId[] = [
    "first_reflection",
    "second_reflection",
    "first_revisit",
    "first_emotional_callback",
    "first_photo_revisit",
    "first_territory_emergence",
  ];
  return ids.map((id) => {
    const { reachedAt, evidence } = milestoneReached(id, entries);
    return { id, reachedAt, evidence };
  });
}

export function buildFirstWeekTimingRecommendations(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): FirstWeekTimingRecommendation[] {
  if (!isWithinFirstWeek(entries)) return [];

  const milestones = detectFirstWeekMilestones(entries);
  const attachment = assessArchiveAttachment(entries);
  const promptState = readFirstWeekPromptState();
  const silence = resolveSilenceIntelligence(entries);
  const recommendations: FirstWeekTimingRecommendation[] = [];

  const hasSecond = milestones.find((m) => m.id === "second_reflection")?.reachedAt;
  const hasRevisit = milestones.find((m) => m.id === "first_revisit")?.reachedAt;
  const reflectionCount = entries.length;

  if (promptState.ignoredCount >= 2 || silence.state === "almost_silent") {
    recommendations.push({
      action: "stay_silent",
      reason: "Repeated prompt ignores or silence intelligence — reduce surfacing",
      priority: 90,
    });
  }

  if (reflectionCount === 1 && !hasRevisit) {
    recommendations.push({
      action: "stay_silent",
      reason: "Single reflection — let first note settle before more prompts",
      priority: 70,
    });
  }

  if (hasSecond && !hasRevisit && attachment.level !== "weak") {
    recommendations.push({
      action: "surface_revisit",
      reason: "Two reflections without revisit — gentle meaningful reopen candidate",
      priority: 82,
    });
  }

  if (reflectionCount >= 1 && reflectionCount < 3) {
    const last = [...entries].sort(
      (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
    )[0];
    const daysSince = daysBetweenKeys(toDayKey(last.createdAt), todayKey());
    if (daysSince >= 2 && promptState.ignoredCount < 2) {
      recommendations.push({
        action: "invite_reflection",
        reason: "Sparse week — optional second note without habit framing",
        priority: 55,
      });
    }
  }

  if (attachment.level === "strong" && hasRevisit) {
    recommendations.push({
      action: "stay_silent",
      reason: "Attachment emerging with revisit — avoid over-prompting",
      priority: 60,
    });
  }

  return recommendations.sort((a, b) => b.priority - a.priority);
}

export function firstSessionComplete(entries: JournalEntry[]): boolean {
  return (
    hasLocalEvent(LAUNCH_EVENTS.firstReflectionCreated) &&
    (hasLocalEvent(LAUNCH_EVENTS.onboardingCompleted) || entries.length >= 1)
  );
}

export function firstRevisitDelayHours(entries: JournalEntry[]): number | null {
  const first = firstReflectionAt(entries);
  const revisit = detectFirstWeekMilestones(entries).find((m) => m.id === "first_revisit")?.reachedAt;
  if (!first || !revisit) return null;
  return Math.round(
    (new Date(revisit).getTime() - new Date(first).getTime()) / (1000 * 60 * 60),
  );
}

export { isWithinFirstWeekOfArchive };
