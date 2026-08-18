import { todayKey } from "@/lib/dates";
import { readLocalEvents } from "@/lib/local-analytics";
import { OPEN_LOOP_EVENTS } from "@/lib/open-loops/open-loop-observation";
import { readActiveOpenLoopsFromStore } from "@/lib/open-loops/open-loop-storage";
import { assertWriteAllowed } from "@/lib/runtime/render-safe";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

const RETURN_DAY_KEY = "voicememory_open_loop_return_prompt_day";
const RETURN_MIN_HOURS = 24;
const RETURN_MAX_HOURS = 72;

export interface OpenLoopReturnOffer {
  openLoopId: string;
  sourceEntryId: string;
  text: string;
  href: string;
}

function quoteSnippet(text: string, max = 40): string {
  const compact = text.replace(/\s+/g, " ").trim();
  if (compact.length <= max) return compact;
  return `${compact.slice(0, max - 1)}…`;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function lastResurfacedAt(openLoopId: string, fallback: string): string {
  const events = readLocalEvents()
    .filter(
      (event) =>
        event.name === OPEN_LOOP_EVENTS.resurfacingShown &&
        event.meta?.openLoopId === openLoopId,
    )
    .sort((a, b) => new Date(b.at).getTime() - new Date(a.at).getTime());

  return events[0]?.at ?? fallback;
}

function reflectionAfterResurface(
  loop: { relatedEntryIds: string[]; sourceEntryId: string },
  resurfaceAt: string,
  entries: JournalEntry[],
): boolean {
  const resurfaceMs = new Date(resurfaceAt).getTime();
  return entries.some(
    (entry) =>
      entry.id !== loop.sourceEntryId &&
      loop.relatedEntryIds.includes(entry.id) &&
      new Date(entry.createdAt).getTime() > resurfaceMs,
  );
}

/** Quiet return path 24–72h after resurfacing — invite a follow-up reflection, not a reminder. */
export function pickOpenLoopReturnOffer(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
  now = Date.now(),
): OpenLoopReturnOffer | null {
  if (!isBrowser()) return null;
  try {
    if (localStorage.getItem(RETURN_DAY_KEY) === todayKey()) return null;
  } catch {
    return null;
  }

  const loops = readActiveOpenLoopsFromStore();
  if (loops.length === 0) return null;

  for (const loop of loops) {
    const resurfaceAt = lastResurfacedAt(loop.openLoopId, loop.lastMentionedAt);
    const resurfaceMs = new Date(resurfaceAt).getTime();
    if (!Number.isFinite(resurfaceMs)) continue;

    const hours = (now - resurfaceMs) / (1000 * 60 * 60);
    if (hours < RETURN_MIN_HOURS || hours > RETURN_MAX_HOURS) continue;
    if (reflectionAfterResurface(loop, resurfaceAt, entries)) continue;

    const anchor = quoteSnippet(loop.strongestAnchorPhrase, 38);
    const step = quoteSnippet(loop.userNextStep, 32);
    const fragment = step.length >= 10 ? step : anchor;
    if (fragment.length < 10) continue;

    return {
      openLoopId: loop.openLoopId,
      sourceEntryId: loop.sourceEntryId,
      text:
        step.length >= 10
          ? `You left a thread open — "${step}". A short reflection keeps it in your words.`
          : `You left a thread open — "${anchor}". A short reflection keeps it in your words.`,
      href: "/#recorder",
    };
  }

  return null;
}

export function recordOpenLoopReturnPromptShown(): void {
  if (!isBrowser()) return;
  assertWriteAllowed("open-loop-return-prompt:recordShown");
  localStorage.setItem(RETURN_DAY_KEY, todayKey());
}

export function previewOpenLoopReturnOffer(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): OpenLoopReturnOffer | null {
  if (!isBrowser()) return null;
  const prior = localStorage.getItem(RETURN_DAY_KEY);
  localStorage.removeItem(RETURN_DAY_KEY);
  const offer = pickOpenLoopReturnOffer(entries);
  if (prior) localStorage.setItem(RETURN_DAY_KEY, prior);
  return offer;
}
