import { buildFollowupPrompt } from "@/lib/conversation/followup-prompts";
import type { ReturnThreadsReport } from "@/types/return-thread";
import type { FollowupPrompt } from "@/types/followup-prompt";
import type { JournalEntry } from "@/types/journal";

/** Map return threads to a single follow-up record prompt — no insight framing. */
export function followupPromptFromReturnThreads(
  report: ReturnThreadsReport | null,
  entries: JournalEntry[],
): FollowupPrompt | null {
  if (!report?.hasData) return null;
  const notes = report.threads.slice(0, 4).map((t) => ({
    id: t.id,
    text: t.continuityLine,
    category: "returned" as const,
    confidence: 60,
    entryId: t.relatedEntryIds[t.relatedEntryIds.length - 1],
  }));
  return buildFollowupPrompt(notes, entries);
}
