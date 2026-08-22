import { assessArchiveAttachment } from "@/lib/retention/archive-attachment-signals";
import { isWithinFirstWeek, readFirstWeekPromptState } from "@/lib/retention/first-week";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { ArchiveValueMomentOffer } from "@/types/first-week-retention";
import type { JournalEntry } from "@/types/journal";

const MOMENTS: Array<{ id: string; text: string; minLevel: "emerging" | "strong" }> = [
  {
    id: "real_period",
    text: "This is starting to become a record of a real period.",
    minLevel: "emerging",
  },
  {
    id: "returned_more_than_once",
    text: "You've returned to this more than once.",
    minLevel: "emerging",
  },
  {
    id: "thoughts_connected",
    text: "Some thoughts are beginning to stay connected.",
    minLevel: "strong",
  },
];

const SHOWN_KEY = "voicememory_archive_value_moment_day";

function shownToday(): boolean {
  if (typeof window === "undefined") return true;
  return localStorage.getItem(SHOWN_KEY) === new Date().toISOString().slice(0, 10);
}

function markShownToday(): void {
  if (typeof window === "undefined") return;
  localStorage.setItem(SHOWN_KEY, new Date().toISOString().slice(0, 10));
}

/** Rare quiet archive-value line — only with behavioral evidence, never scores. */
export function pickArchiveValueMoment(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): ArchiveValueMomentOffer | null {
  if (!isWithinFirstWeek(entries)) return null;
  if (entries.length < 2) return null;
  if (shownToday()) return null;

  const attachment = assessArchiveAttachment(entries);
  if (attachment.level === "weak") return null;

  const promptState = readFirstWeekPromptState();
  if (promptState.ignoredCount >= 2) return null;

  const eligible = MOMENTS.filter((moment) => {
    if (moment.minLevel === "strong") return attachment.level === "strong";
    return attachment.level === "emerging" || attachment.level === "strong";
  });

  const repeatReturn = attachment.signals.some((s) => s.id.startsWith("repeat_"));
  const pick =
    repeatReturn && eligible.find((m) => m.id === "returned_more_than_once")
      ? eligible.find((m) => m.id === "returned_more_than_once")
      : attachment.level === "strong" && eligible.find((m) => m.id === "thoughts_connected")
        ? eligible.find((m) => m.id === "thoughts_connected")
        : eligible[0];

  if (!pick) return null;
  markShownToday();
  return { id: pick.id, text: pick.text };
}
