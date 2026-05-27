import { buildReturnThreads } from "@/lib/continuity/return-threads";
import { gateContinuityLine } from "@/lib/continuity/continuity-quality-gate";
import { entryContinuitySnippet } from "@/lib/product/human-continuity-ui";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { ReturnThread } from "@/types/return-thread";
import type { JournalEntry } from "@/types/journal";

export interface MobileHomeSecondarySurface {
  kind: "return_thread" | "latest_reflection";
  thread?: ReturnThread;
  entry?: JournalEntry;
  snippet?: string;
}

/** One card below mic — return thread beats latest reflection when quality passes. */
export function pickMobileHomeSecondary(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): MobileHomeSecondarySurface | null {
  const report = buildReturnThreads(entries);
  const thread = report.threads.find(
    (t) => gateContinuityLine(t.continuityLine) && (t.anchorQuote || t.latestQuote),
  );
  if (thread) {
    return { kind: "return_thread", thread };
  }

  const sorted = [...entries]
    .filter((e) => e.reflectionPending !== true)
    .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
  const latest = sorted[0];
  if (!latest) return null;

  const snippet = entryContinuitySnippet(latest);
  if (!snippet || snippet === "Voice reflection") return null;
  return { kind: "latest_reflection", entry: latest, snippet };
}
