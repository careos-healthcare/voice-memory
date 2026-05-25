import { todayKey } from "@/lib/dates";
import { getMemoryEligibleEntries } from "@/lib/storage";
import {
  trackOnboardingClarityEvent,
  ONBOARDING_CLARITY_EVENTS,
} from "@/lib/onboarding/onboarding-observation";
import type { CalmComprehensionOffer } from "@/types/onboarding-clarity";

const STATE_KEY = "voicememory_calm_comprehension";

const PROMPTS: CalmComprehensionOffer[] = [
  { id: "no_organize", text: "You don't need to organize anything here." },
  {
    id: "accumulate",
    text: "This becomes more meaningful as moments accumulate.",
  },
  { id: "unfinished", text: "You can leave unfinished thoughts." },
];

interface ComprehensionState {
  lastShownDay: string | null;
  sessionCount: number;
  ignoredCount: number;
  shownIds: string[];
}

function readState(): ComprehensionState {
  if (typeof window === "undefined") {
    return { lastShownDay: null, sessionCount: 0, ignoredCount: 0, shownIds: [] };
  }
  try {
    const raw = localStorage.getItem(STATE_KEY);
    if (!raw) return { lastShownDay: null, sessionCount: 0, ignoredCount: 0, shownIds: [] };
    return JSON.parse(raw) as ComprehensionState;
  } catch {
    return { lastShownDay: null, sessionCount: 0, ignoredCount: 0, shownIds: [] };
  }
}

function writeState(state: ComprehensionState): void {
  if (typeof window === "undefined") return;
  localStorage.setItem(STATE_KEY, JSON.stringify(state));
}

export function recordComprehensionSession(): void {
  const state = readState();
  state.sessionCount += 1;
  writeState(state);
}

export function recordComprehensionIgnored(): void {
  const state = readState();
  state.ignoredCount += 1;
  writeState(state);
  trackOnboardingClarityEvent(ONBOARDING_CLARITY_EVENTS.comprehensionIgnored);
}

/** Preview next prompt without persisting (debug). */
export function peekCalmComprehensionPrompt(): CalmComprehensionOffer | null {
  const entries = getMemoryEligibleEntries();
  if (entries.length === 0) return null;
  const state = readState();
  if (state.ignoredCount >= 2) return null;
  if (state.lastShownDay === todayKey()) return null;
  if (state.sessionCount > 0 && state.sessionCount % 3 !== 0) return null;
  return PROMPTS.find((p) => !state.shownIds.includes(p.id)) ?? PROMPTS[0];
}

/** Max one line every few sessions; suppress after ignores. */
export function pickCalmComprehensionPrompt(): CalmComprehensionOffer | null {
  const entries = getMemoryEligibleEntries();
  if (entries.length === 0) return null;

  const state = readState();
  if (state.ignoredCount >= 2) return null;
  if (state.lastShownDay === todayKey()) return null;
  if (state.sessionCount > 0 && state.sessionCount % 3 !== 0) return null;

  const next = PROMPTS.find((p) => !state.shownIds.includes(p.id)) ?? PROMPTS[0];
  writeState({
    ...state,
    lastShownDay: todayKey(),
    shownIds: [...state.shownIds, next.id].slice(-6),
  });
  trackOnboardingClarityEvent(ONBOARDING_CLARITY_EVENTS.comprehensionShown, { id: next.id });
  return next;
}
