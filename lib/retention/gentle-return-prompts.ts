import { todayKey } from "@/lib/dates";
import { WEDGE_RESURFACING } from "@/lib/product-copy";
import { pickFirstMeaningfulRevisitCandidate } from "@/lib/revisit/first-meaningful-revisit";
import {
  buildFirstWeekTimingRecommendations,
  isWithinFirstWeek,
  readFirstWeekPromptState,
  recordGentlePromptShown,
} from "@/lib/retention/first-week";
import { getSilenceIntelligenceEffects } from "@/lib/restraint/silence-intelligence";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { GentleReturnPromptOffer, GentleReturnPromptId } from "@/types/first-week-retention";
import type { JournalEntry } from "@/types/journal";

const PROMPT_COPY: Record<GentleReturnPromptId, string> = {
  week_disappearing: "You may want to leave another note before this week disappears.",
  earlier_this_week: "Something from earlier this week may feel different now.",
  continuity_building: WEDGE_RESURFACING.similarWordsBefore,
  meaningful_revisit: "Something from earlier this week may feel different now.",
};

const BLOCKED_TERMS = [
  "streak",
  "daily habit",
  "don't miss",
  "hurry",
  "urgent",
  "log in",
  "keep your streak",
  "productivity",
  "goal",
  "fomo",
  "engagement",
];

export function isGentlePromptCopyAllowed(text: string): boolean {
  const lower = text.toLowerCase();
  return !BLOCKED_TERMS.some((term) => lower.includes(term));
}

function topRecommendationAction(
  entries: JournalEntry[],
): "surface_revisit" | "stay_silent" | "invite_reflection" | null {
  const recs = buildFirstWeekTimingRecommendations(entries);
  return recs[0]?.action ?? null;
}

function buildGentleReturnPromptOffer(
  entries: JournalEntry[],
  options: { recordShown: boolean },
): GentleReturnPromptOffer | null {
  if (!isWithinFirstWeek(entries)) return null;
  if (entries.length === 0) return null;

  const state = readFirstWeekPromptState();
  if (state.lastShownDay === todayKey()) return null;
  if (state.ignoredCount >= 3) return null;

  const silence = getSilenceIntelligenceEffects(entries);
  if (silence.suppressMemoryNotes || silence.essentialsOnly) return null;

  const action = topRecommendationAction(entries);
  if (action === "stay_silent") return null;

  let id: GentleReturnPromptId;
  let href: string | undefined;
  let entryId: string | undefined;

  if (action === "surface_revisit") {
    const candidate = pickFirstMeaningfulRevisitCandidate(entries);
    if (candidate) {
      id = "meaningful_revisit";
      href = `/entry/${candidate.entryId}`;
      entryId = candidate.entryId;
    } else {
      id = "earlier_this_week";
      href = "/memory";
    }
  } else if (entries.length < 3) {
    id = "week_disappearing";
  } else {
    id = "continuity_building";
    href = "/memory";
  }

  const text = PROMPT_COPY[id];
  if (!isGentlePromptCopyAllowed(text)) return null;

  if (options.recordShown) {
    recordGentlePromptShown(id);
  }

  return { id, text, href, entryId };
}

/** At most one gentle return prompt per calendar day during the first week. */
export function pickGentleReturnPrompt(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): GentleReturnPromptOffer | null {
  return buildGentleReturnPromptOffer(entries, { recordShown: true });
}

export function previewGentleReturnPrompt(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): GentleReturnPromptOffer | null {
  return buildGentleReturnPromptOffer(entries, { recordShown: false });
}
