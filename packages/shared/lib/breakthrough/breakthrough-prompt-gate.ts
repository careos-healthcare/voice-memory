import { todayKey } from "@/lib/dates";

const STATE_KEY = "voicememory_breakthrough_prompt_state";

interface PromptGateState {
  lastShownDay: string | null;
  eligibleSurfaces: number;
  dismissCount: number;
  shownPromptIds: string[];
}

function getStorage(): Storage | null {
  if (typeof window !== "undefined") return localStorage;
  if (typeof globalThis.localStorage !== "undefined") {
    return globalThis.localStorage as Storage;
  }
  return null;
}

function readState(): PromptGateState {
  const store = getStorage();
  if (!store) {
    return { lastShownDay: null, eligibleSurfaces: 0, dismissCount: 0, shownPromptIds: [] };
  }
  try {
    const raw = store.getItem(STATE_KEY);
    if (!raw) {
      return { lastShownDay: null, eligibleSurfaces: 0, dismissCount: 0, shownPromptIds: [] };
    }
    return JSON.parse(raw) as PromptGateState;
  } catch {
    return { lastShownDay: null, eligibleSurfaces: 0, dismissCount: 0, shownPromptIds: [] };
  }
}

function writeState(state: PromptGateState): void {
  getStorage()?.setItem(STATE_KEY, JSON.stringify(state));
}

/** Call when a surface becomes eligible (feedback saved). */
export function recordBreakthroughEligibleSurface(): void {
  const state = readState();
  state.eligibleSurfaces += 1;
  writeState(state);
}

export function recordBreakthroughPromptShown(promptId: string): void {
  const state = readState();
  state.lastShownDay = todayKey();
  if (!state.shownPromptIds.includes(promptId)) {
    state.shownPromptIds.push(promptId);
  }
  writeState(state);
}

export function recordBreakthroughPromptDismissed(): void {
  const state = readState();
  state.dismissCount += 1;
  writeState(state);
}

/** Max one prompt per day; every 4th eligible surface; stop after 4 dismissals. */
export function shouldOfferBreakthroughPrompt(): boolean {
  const state = readState();
  if (state.dismissCount >= 4) return false;
  if (state.lastShownDay === todayKey()) return false;
  if (state.eligibleSurfaces === 0) return false;
  return state.eligibleSurfaces % 4 === 0;
}

export function readShownBreakthroughPromptIds(): string[] {
  return readState().shownPromptIds;
}

export function clearBreakthroughPromptGateForEval(): void {
  getStorage()?.removeItem(STATE_KEY);
}
