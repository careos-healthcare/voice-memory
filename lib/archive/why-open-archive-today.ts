import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { buildArchiveReputationMovement } from "@/lib/archive/archive-reputation-movement";
import { buildArchiveSilenceView } from "@/lib/archive/archive-silence";
import { buildSessionMovementSummary } from "@/lib/archive/session-movement-summary";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

export const WHY_OPEN_ARCHIVE_LINES = [
  "The archive became more certain.",
  "New evidence appeared.",
  "A belief was challenged.",
  "A pattern has not appeared recently.",
  "The archive changed its view.",
] as const;

export interface WhyOpenArchiveTodayView {
  line: string;
}

export function buildWhyOpenArchiveToday(
  entriesInput?: JournalEntry[],
): WhyOpenArchiveTodayView | null {
  const entries = entriesInput ?? getMemoryEligibleEntries();
  if (entries.length < 2) return null;

  const movement = buildArchiveReputationMovement(entries);
  if (movement?.headline.includes("reputation increased")) {
    return { line: WHY_OPEN_ARCHIVE_LINES[0] };
  }
  if (movement?.headline.includes("strengthened")) {
    return { line: WHY_OPEN_ARCHIVE_LINES[1] };
  }
  if (movement?.headline.includes("lowered confidence") || movement?.headline.includes("challenged")) {
    return { line: WHY_OPEN_ARCHIVE_LINES[2] };
  }

  const silence = buildArchiveSilenceView(entries);
  const fading = silence?.signals.find((s) => s.kind === "pattern_fading");
  if (fading) {
    return { line: WHY_OPEN_ARCHIVE_LINES[3] };
  }

  const session = buildSessionMovementSummary(entries, { browseSurface: true });
  if (session?.kind === "belief_changed") {
    return { line: WHY_OPEN_ARCHIVE_LINES[4] };
  }

  const belief = buildArchiveBeliefView(entries);
  if (belief?.status === "strengthening") {
    return { line: WHY_OPEN_ARCHIVE_LINES[0] };
  }
  if (belief?.status === "weakening") {
    return { line: WHY_OPEN_ARCHIVE_LINES[2] };
  }
  if (session?.kind === "new_evidence_added") {
    return { line: WHY_OPEN_ARCHIVE_LINES[1] };
  }

  if (belief?.changeLines.some((l) => /contradict/i.test(l.text))) {
    return { line: WHY_OPEN_ARCHIVE_LINES[2] };
  }

  return { line: WHY_OPEN_ARCHIVE_LINES[1] };
}
