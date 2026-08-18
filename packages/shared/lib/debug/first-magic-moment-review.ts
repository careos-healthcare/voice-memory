import { homepageResurfacingNotes } from "@/lib/memory/resurfacing";
import { homepageRevisitationNotes } from "@/lib/memory/revisitation";
import {
  computeMagicMomentMetrics,
  listMagicMomentEvents,
  qualifyMagicCandidate,
} from "@/lib/retention/first-magic-moment";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { MagicMomentDebugReport } from "@/types/first-magic-moment";

/** Internal review — no user-facing surfaces. */
export function buildFirstMagicMomentDebugReport(): MagicMomentDebugReport {
  const entries = getMemoryEligibleEntries();
  const candidates = [
    ...homepageResurfacingNotes(entries, 6),
    ...homepageRevisitationNotes(entries),
  ];

  const seen = new Set<string>();
  const qualifications = candidates
    .map((note) => qualifyMagicCandidate(note, entries))
    .filter((row): row is NonNullable<typeof row> => {
      if (!row || seen.has(row.noteId)) return false;
      seen.add(row.noteId);
      return true;
    })
    .slice(0, 12);

  const metrics = computeMagicMomentMetrics(entries);
  const recentEvents = listMagicMomentEvents(48);

  return {
    generatedAt: new Date().toISOString(),
    hasData: recentEvents.length > 0 || qualifications.length > 0,
    metrics,
    recentEvents,
    qualifications,
  };
}
