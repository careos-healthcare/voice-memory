import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { trackLocalEvent } from "@/lib/local-analytics";
import { getMemoryEligibleEntries } from "@/lib/storage";

export const ARCHIVE_LOSS_PROMPT_EVENTS = {
  seen: "archive_loss_prompt_seen",
  clicked: "archive_loss_prompt_clicked",
  dismissed: "archive_loss_prompt_dismissed",
} as const;

export const FIRST_WORKING_BELIEF_SEEN_KEY = "voicememory_first_working_belief_seen";
const LOSS_PROMPT_LAST_SHOWN_KEY = "voicememory_archive_loss_prompt_last_shown";
const LOSS_PROMPT_DISMISSED_KEY = "voicememory_archive_loss_prompt_dismissed";
const LOSS_COOLDOWN_MS = 7 * 24 * 60 * 60 * 1000;
const MIN_REFLECTIONS = 5;

function getStorage(): Storage | null {
  if (typeof window === "undefined") return null;
  return localStorage;
}

export function markFirstWorkingBeliefSeenIfNeeded(): void {
  const store = getStorage();
  if (!store || store.getItem(FIRST_WORKING_BELIEF_SEEN_KEY) === "1") return;
  const entries = getMemoryEligibleEntries().filter((e) => e.reflectionPending !== true);
  if (entries.length < MIN_REFLECTIONS) return;
  if (!buildArchiveBeliefView(entries)) return;
  store.setItem(FIRST_WORKING_BELIEF_SEEN_KEY, "1");
}

export function hasSeenFirstWorkingBelief(): boolean {
  return getStorage()?.getItem(FIRST_WORKING_BELIEF_SEEN_KEY) === "1";
}

export function canShowArchiveLossPrompt(
  isSignedIn: boolean,
  now = Date.now(),
): boolean {
  if (isSignedIn) return false;
  const store = getStorage();
  if (!store) return false;
  if (store.getItem(LOSS_PROMPT_DISMISSED_KEY) === "1") return false;

  const entries = getMemoryEligibleEntries().filter((e) => e.reflectionPending !== true);
  if (entries.length < MIN_REFLECTIONS) return false;
  if (!buildArchiveBeliefView(entries)) return false;
  if (!hasSeenFirstWorkingBelief()) return false;

  const last = store.getItem(LOSS_PROMPT_LAST_SHOWN_KEY);
  if (last && now - new Date(last).getTime() < LOSS_COOLDOWN_MS) return false;

  return true;
}

export function markArchiveLossPromptShown(): void {
  getStorage()?.setItem(LOSS_PROMPT_LAST_SHOWN_KEY, new Date().toISOString());
  trackLocalEvent(ARCHIVE_LOSS_PROMPT_EVENTS.seen, {});
}

export function trackArchiveLossPromptClicked(): void {
  trackLocalEvent(ARCHIVE_LOSS_PROMPT_EVENTS.clicked, {});
}

export function dismissArchiveLossPrompt(): void {
  getStorage()?.setItem(LOSS_PROMPT_DISMISSED_KEY, "1");
  trackLocalEvent(ARCHIVE_LOSS_PROMPT_EVENTS.dismissed, {});
}

export function clearArchiveLossPromptForEval(): void {
  const store = getStorage();
  if (!store) return;
  store.removeItem(LOSS_PROMPT_LAST_SHOWN_KEY);
  store.removeItem(LOSS_PROMPT_DISMISSED_KEY);
  store.removeItem(FIRST_WORKING_BELIEF_SEEN_KEY);
}
