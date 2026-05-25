import { pickFirstMeaningfulRevisitCandidate } from "@/lib/revisit/first-meaningful-revisit";
import { REVISIT_REWARD_COPY } from "@/lib/refinement/knows-me-moments";
import { hasLocalEvent } from "@/lib/local-analytics";
import {
  isInFirstAhaWindow,
  completeFirstSessionStep,
} from "@/lib/onboarding/first-session-flow";
import { trackFirstAhaMoment } from "@/lib/onboarding/onboarding-observation";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { FirstAhaOffer } from "@/types/onboarding-clarity";
import type { MemoryNote } from "@/types/memory-note";

const SHOWN_KEY = "voicememory_first_aha_shown";

const SURPRISE_LINES = [
  REVISIT_REWARD_COPY.notNamedYet,
  REVISIT_REWARD_COPY.usedToTakeSpace,
  REVISIT_REWARD_COPY.beforeThingsChanged,
  "You said this differently than you might remember.",
] as const;

function alreadyShown(): boolean {
  if (typeof window === "undefined") return true;
  return localStorage.getItem(SHOWN_KEY) === "1" || hasLocalEvent("first_aha_moment");
}

function markShown(): void {
  if (typeof window === "undefined") return;
  localStorage.setItem(SHOWN_KEY, "1");
}

function buildOfferFromCandidate(
  candidate: NonNullable<ReturnType<typeof pickFirstMeaningfulRevisitCandidate>>,
): FirstAhaOffer | null {
  const text =
    SURPRISE_LINES.find((line) => line === candidate.firstLine) ??
    candidate.firstLine ??
    SURPRISE_LINES[0];

  if (!text || text.length < 12) return null;

  return {
    entryId: candidate.entryId,
    text,
    noteId: `first-aha-${candidate.entryId}`,
    href: `/entry/${candidate.entryId}`,
  };
}

/** Preview for debug — no persistence or analytics. */
export function peekFirstAhaCallback(
  entries = getMemoryEligibleEntries(),
): FirstAhaOffer | null {
  if (!isInFirstAhaWindow()) return null;
  if (entries.length < 2) return null;
  if (alreadyShown()) return null;
  const candidate = pickFirstMeaningfulRevisitCandidate(entries);
  if (!candidate || candidate.payoffScore < 54) return null;
  return buildOfferFromCandidate(candidate);
}

/** One surprise callback in the 24–72h window — “Oh. I forgot I said that.” */
export function pickFirstAhaCallback(
  entries = getMemoryEligibleEntries(),
): FirstAhaOffer | null {
  const offer = peekFirstAhaCallback(entries);
  if (!offer) return null;

  markShown();
  trackFirstAhaMoment(offer.entryId, offer.noteId);
  completeFirstSessionStep("continuity_moment");
  return offer;
}

export function firstAhaAsMemoryNote(offer: FirstAhaOffer): MemoryNote {
  return {
    id: offer.noteId,
    text: offer.text,
    entryId: offer.entryId,
    category: "returned",
    confidence: 78,
  };
}
