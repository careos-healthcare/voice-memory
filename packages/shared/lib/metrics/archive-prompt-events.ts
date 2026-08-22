import { readLocalEvents, trackLocalEvent } from "@/lib/local-analytics";
import type { ArchivePromptTypeId } from "@/types/archive-prompt";

export const ARCHIVE_PROMPT_EVENT_NAMES = {
  shown: "archive_prompt_shown" as const,
  selected: "archive_prompt_selected" as const,
  refreshed: "archive_prompt_refreshed" as const,
  recorded: "archive_prompt_recorded" as const,
};

export function trackArchivePromptShown(meta: {
  mode: string;
  promptIds: string;
  surface: string;
}): void {
  trackLocalEvent(ARCHIVE_PROMPT_EVENT_NAMES.shown, meta);
}

export function trackArchivePromptSelected(meta: {
  promptId: string;
  type: ArchivePromptTypeId;
  surface: string;
}): void {
  trackLocalEvent(ARCHIVE_PROMPT_EVENT_NAMES.selected, meta);
}

export function trackArchivePromptRefreshed(meta: {
  mode: string;
  surface: string;
  refreshIndex: string;
}): void {
  trackLocalEvent(ARCHIVE_PROMPT_EVENT_NAMES.refreshed, meta);
}

export function trackArchivePromptRecorded(meta: {
  promptId: string;
  type: ArchivePromptTypeId;
  surface: string;
}): void {
  trackLocalEvent(ARCHIVE_PROMPT_EVENT_NAMES.recorded, meta);
}

export function readArchivePromptEvents(): ReturnType<typeof readLocalEvents> {
  const names = new Set<string>(Object.values(ARCHIVE_PROMPT_EVENT_NAMES));
  return readLocalEvents().filter((e) => names.has(e.name));
}

export function archivePromptConversionRate(): number | null {
  const events = readArchivePromptEvents();
  const selected = events.filter((e) => e.name === ARCHIVE_PROMPT_EVENT_NAMES.selected).length;
  const recorded = events.filter((e) => e.name === ARCHIVE_PROMPT_EVENT_NAMES.recorded).length;
  if (selected === 0) return null;
  return Math.round((recorded / selected) * 100);
}

export function clearArchivePromptEventsForEval(): void {
  if (typeof window === "undefined") return;
  try {
    const raw = localStorage.getItem("voicememory_local_events");
    if (!raw) return;
    const names = new Set<string>(Object.values(ARCHIVE_PROMPT_EVENT_NAMES));
    const events = JSON.parse(raw) as Array<{ name: string }>;
    const filtered = events.filter((e) => !names.has(e.name));
    localStorage.setItem("voicememory_local_events", JSON.stringify(filtered));
  } catch {
    /* ignore */
  }
}
