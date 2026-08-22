import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { buildContradictionHistoryView } from "@/lib/archive/contradiction-history";
import { buildArchiveStateDelta } from "@/lib/archive/archive-state-snapshot";
import { buildArchiveOpenQuestions } from "@/lib/archive/archive-open-question";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

const WATCH = {
  conflicting: "The archive has conflicting evidence.",
  stale: "This belief has not appeared recently.",
  changing: "This belief may be changing.",
  stress: "The archive is paying attention to work stress.",
  gathering: "The archive is still gathering evidence for this belief.",
} as const;

function daysSince(iso: string): number {
  const ms = Date.now() - new Date(iso).getTime();
  return Math.floor(ms / (24 * 60 * 60 * 1000));
}

/** Single-sentence watch line from internal archive signals. */
export function buildArchiveWatchItemV3(
  entriesInput?: JournalEntry[],
): string {
  const entries = (entriesInput ?? getMemoryEligibleEntries()).filter(
    (e) => e.reflectionPending !== true,
  );
  if (entries.length === 0) return WATCH.gathering;

  const belief = buildArchiveBeliefView(entries);
  if (!belief) return WATCH.gathering;

  const contradiction = buildContradictionHistoryView(entries);
  if (contradiction) {
    return WATCH.conflicting;
  }

  const delta = buildArchiveStateDelta(entries);
  if (delta?.hasChanges) {
    return WATCH.changing;
  }

  const sorted = [...entries].sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
  );
  const last = sorted[0];
  if (last && daysSince(last.createdAt) >= 14 && entries.length >= 5) {
    return WATCH.stale;
  }

  const areas = belief.evidence.lifeAreas.map((a) => a.toLowerCase());
  if (areas.some((a) => a.includes("work") || a.includes("stress"))) {
    return WATCH.stress;
  }

  const open = buildArchiveOpenQuestions(entries);
  if (open.length > 0 && open[0]?.text) {
    const q = open[0].text.replace(/\?+$/, "").trim();
    if (q.length > 12 && q.length < 120) {
      return `The archive is paying attention to ${q.charAt(0).toLowerCase()}${q.slice(1)}.`;
    }
  }

  if (belief.status === "weakening" || belief.status === "under_review") {
    return WATCH.changing;
  }

  return WATCH.gathering;
}
