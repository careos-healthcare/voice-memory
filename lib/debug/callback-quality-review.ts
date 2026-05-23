import {
  buildSourceEntry,
  callbackInteractionSignals,
} from "@/lib/callback-interaction-signals";
import { buildFollowupPrompt } from "@/lib/conversation/followup-prompts";
import { buildArchiveGrowthReport } from "@/lib/memory/archive-growth";
import { buildChangeMomentsReport } from "@/lib/memory/change-moments";
import { buildContinuityDepthReport } from "@/lib/memory/continuity-depth";
import { buildEmotionalMilestonesReport } from "@/lib/memory/milestones";
import { buildMemoryRemindersReport } from "@/lib/memory/memory-reminders";
import { buildRelationshipContinuityReport } from "@/lib/memory/relationship-continuity";
import { buildResurfacingReport } from "@/lib/memory/resurfacing";
import { buildRevisitationReport } from "@/lib/memory/revisitation";
import { buildFamiliarityReport } from "@/lib/memory/familiarity";
import { buildFamiliarityResurfacingReport } from "@/lib/memory/familiarity-resurfacing";
import { buildRhythmReport } from "@/lib/memory/rhythm-memory";
import { buildTimeMemoryReport } from "@/lib/memory/time-memory";
import { weightMemoryNote } from "@/lib/memory/emotional-weight";
import { buildContinuityMomentsReport } from "@/lib/patterns/continuity-moments";
import { buildMemoryNotesReport, thenVsNowToNote } from "@/lib/patterns/memory-notes";
import { countLabeledCallbacks } from "@/lib/debug/callback-review-labels";
import { detectRewriteCandidateFlags } from "@/lib/debug/callback-rewrite-detection";
import type {
  CallbackQualityReviewReport,
  CallbackReviewItem,
  CallbackReviewKind,
  CallbackSourceEntry,
} from "@/types/callback-quality-review";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function entryIdsFromNote(note: MemoryNote): string[] {
  return [note.pastEntryId, note.entryId].filter(Boolean) as string[];
}

function sourceEntriesForIds(entryIds: string[]): CallbackSourceEntry[] {
  return [...new Set(entryIds)]
    .map((id) => buildSourceEntry(id))
    .filter((entry): entry is CallbackSourceEntry => Boolean(entry));
}

function whyFromId(id: string, fallback: string): string {
  if (id.startsWith("tvn-")) {
    return "Then-vs-now comparison on a recurring subject with enough archive distance.";
  }
  if (id.startsWith("revisit-")) {
    return "Revisitation detector linked a recent reflection to an older entry.";
  }
  if (id.startsWith("resurface-")) {
    return "Resurfacing detector found a topic, person, or phrase returning after silence.";
  }
  if (id.startsWith("change-") || id.startsWith("moment-change-")) {
    return "Change moment grounded in language shift between two reflections.";
  }
  if (id.startsWith("continuity-")) {
    return "Continuity callback across multiple reflections on the same thread.";
  }
  if (id.startsWith("milestone-")) {
    return "Emotional milestone threshold crossed in the archive timeline.";
  }
  if (id.startsWith("relationship-")) {
    return "Relationship continuity shift in how a person or place appears over time.";
  }
  if (id.startsWith("archive-")) {
    return "Archive growth signal — accumulated continuity across weeks or months.";
  }
  if (id.startsWith("mem-reminder-")) {
    return "Memory reminder candidate with revisit distance and shared theme evidence.";
  }
  if (id.startsWith("continuity-depth-")) {
    return "Continuity depth indicator — compounded threads, revisit links, and landmarks.";
  }
  return fallback;
}

function surfacesForKind(kind: CallbackReviewKind): string[] {
  switch (kind) {
    case "memory_callback":
    case "then_vs_now":
      return ["homepage", "memory", "entry", "timeline"];
    case "milestone":
      return ["memory", "timeline", "monthly", "entry"];
    case "relationship_continuity":
      return ["memory", "threads", "entry"];
    case "continuity_depth":
      return ["homepage", "memory"];
    case "memory_reminder":
      return ["homepage", "reminders"];
    default:
      return ["homepage", "memory", "timeline", "monthly", "entry"];
  }
}

function noteToItem(
  note: MemoryNote,
  kind: CallbackReviewKind,
  sorted: JournalEntry[],
  whySurfaced: string,
  surfaces?: string[],
): CallbackReviewItem {
  const entryIds = entryIdsFromNote(note);
  const emotionalWeight = weightMemoryNote(note, sorted);
  const rewriteFlags = detectRewriteCandidateFlags({
    text: note.text,
    beforeQuote: note.pastQuote,
    afterQuote: note.currentQuote,
    kind,
  });
  const signals = callbackInteractionSignals(note.id, entryIds);
  const followup = buildFollowupPrompt([note]);
  const followupPrompt = followup?.text;

  return {
    id: note.id,
    kind,
    text: note.text,
    surfaces: surfaces ?? surfacesForKind(kind),
    sourceEntries: sourceEntriesForIds(entryIds),
    beforeQuote: note.pastQuote,
    afterQuote: note.currentQuote,
    beforeDateLabel: note.pastDateLabel,
    afterDateLabel: note.currentDateLabel,
    whySurfaced,
    emotionalWeight,
    confidence: note.confidence,
    rewriteFlags,
    signals,
    followupNoteId: note.id,
    followupPrompt,
    continuedFollowup: signals.followupContinued,
  };
}

function lineToItem(
  id: string,
  kind: CallbackReviewKind,
  text: string,
  sorted: JournalEntry[],
  whySurfaced: string,
  entryIds: string[] = [],
  strength = 60,
  surfaces?: string[],
): CallbackReviewItem {
  const rewriteFlags = detectRewriteCandidateFlags({ text, kind });
  const signals = callbackInteractionSignals(id, entryIds);
  return {
    id,
    kind,
    text,
    surfaces: surfaces ?? surfacesForKind(kind),
    sourceEntries: sourceEntriesForIds(entryIds),
    whySurfaced,
    emotionalWeight: strength,
    confidence: strength,
    rewriteFlags,
    signals,
    continuedFollowup: signals.followupContinued,
  };
}

function dedupeItems(items: CallbackReviewItem[]): CallbackReviewItem[] {
  const seen = new Set<string>();
  return items.filter((item) => {
    const key = `${item.kind}:${item.id}:${item.text.slice(0, 48)}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

/** Collect surfaced callbacks for manual quality review — debug only. */
export function buildCallbackQualityReviewReport(
  entries: JournalEntry[],
): CallbackQualityReviewReport {
  const sorted = sortedEntries(entries);
  if (sorted.length === 0) {
    return { items: [], rewriteCandidateCount: 0, labeledCount: 0, hasData: false };
  }

  const items: CallbackReviewItem[] = [];
  const latest = sorted[sorted.length - 1];

  const memoryNotes = buildMemoryNotesReport(sorted, {
    context: "memory",
    maxTotal: 24,
    includeLandmarks: true,
  });

  for (const note of [...memoryNotes.changed, ...memoryNotes.faded, ...memoryNotes.returned]) {
    const kind: CallbackReviewKind = note.id.startsWith("tvn-") ? "then_vs_now" : "memory_callback";
    items.push(
      noteToItem(
        note,
        kind,
        sorted,
        whyFromId(note.id, "Primary memory callback from continuity engine."),
      ),
    );
  }

  for (const note of memoryNotes.landmarks) {
    items.push(
      noteToItem(
        note,
        "continuity_line",
        sorted,
        "Landmark moment spanning multiple reflections in the archive.",
      ),
    );
  }

  const continuity = buildContinuityMomentsReport(sorted, {
    context: "memory",
    callbackLimit: 24,
    landmarkLimit: 12,
  });

  for (const comparison of continuity.thenVsNowList ?? []) {
    const note = thenVsNowToNote(comparison, sorted);
    if (!note) continue;
    items.push(
      noteToItem(
        note,
        "then_vs_now",
        sorted,
        `Subject "${comparison.subject}" compared across ${comparison.then.dateLabel} and ${comparison.now.dateLabel}.`,
      ),
    );
  }

  const resurfacing = buildResurfacingReport(sorted, { limit: 16, surface: "memory" });
  for (const note of resurfacing.notes) {
    items.push(
      noteToItem(
        {
          id: note.id,
          text: note.text,
          category: "returned",
          confidence: note.strength,
          pastQuote: note.pastQuote,
          currentQuote: note.currentQuote,
          pastDateLabel: note.pastDateLabel,
          currentDateLabel: note.currentDateLabel,
          pastEntryId: note.pastEntryId,
          entryId: note.entryId,
        },
        "resurfacing",
        sorted,
        `Resurfacing kind inferred from note id: ${note.id.split("-").slice(1, 3).join(" ")}.`,
      ),
    );
  }

  const revisitation = buildRevisitationReport(sorted, { context: "memory", limit: 16 });
  for (const note of revisitation.notes) {
    items.push(
      noteToItem(
        {
          id: note.id,
          text: note.text,
          category: "returned",
          confidence: note.strength,
          pastQuote: note.pastQuote,
          currentQuote: note.currentQuote,
          pastEntryId: note.pastEntryId,
          entryId: note.entryId,
        },
        "revisitation",
        sorted,
        `Revisitation kind: ${note.kind.replace(/_/g, " ")}.`,
      ),
    );
  }

  const changeMoments = buildChangeMomentsReport(sorted, { context: "memory", limit: 16 });
  for (const note of changeMoments.notes) {
    items.push(
      noteToItem(
        {
          id: note.id,
          text: note.text,
          category: "changed",
          confidence: note.strength,
          pastQuote: note.pastQuote,
          currentQuote: note.currentQuote,
          pastDateLabel: note.pastDateLabel,
          currentDateLabel: note.currentDateLabel,
          pastEntryId: note.pastEntryId,
          entryId: note.entryId,
        },
        "change_moment",
        sorted,
        `Change moment kind: ${note.kind.replace(/_/g, " ")}.`,
      ),
    );
  }

  const milestones = buildEmotionalMilestonesReport(sorted, {
    context: "memory",
    limit: 12,
    record: false,
  });
  for (const milestone of milestones.milestones) {
    const entryIds = [milestone.entryId, milestone.pastEntryId].filter(Boolean) as string[];
    items.push(
      lineToItem(
        milestone.id,
        "milestone",
        milestone.text,
        sorted,
        `Milestone kind: ${milestone.kind.replace(/_/g, " ")}.`,
        entryIds,
        milestone.strength,
      ),
    );
  }

  const relationship = buildRelationshipContinuityReport(sorted, {
    context: "memory",
    limit: 12,
  });
  for (const note of relationship.notes) {
    const entryIds = [note.entryId, note.pastEntryId].filter(Boolean) as string[];
    items.push(
      lineToItem(
        note.id,
        "relationship_continuity",
        note.text,
        sorted,
        `Relationship continuity: ${note.kind.replace(/_/g, " ")} around ${note.entityName}.`,
        entryIds,
        note.strength,
      ),
    );
  }

  const archive = buildArchiveGrowthReport(sorted, {
    context: "memory",
    meaningfulTiming: true,
    record: false,
  });
  for (const note of archive.notes) {
    const entryIds = [note.pastEntryId, note.entryId].filter(Boolean) as string[];
    items.push(
      lineToItem(
        note.id,
        "archive_growth",
        note.text,
        sorted,
        `Archive growth kind: ${note.kind.replace(/_/g, " ")}.`,
        entryIds,
        note.strength,
      ),
    );
  }

  const reminders = buildMemoryRemindersReport(sorted, {
    context: "reminders",
    limit: 8,
    record: false,
  });
  for (const reminder of reminders.reminders) {
    const entryIds = [reminder.pastEntryId, reminder.entryId].filter(Boolean) as string[];
    items.push(
      lineToItem(
        reminder.id,
        "memory_reminder",
        reminder.text,
        sorted,
        `Reminder kind: ${reminder.kind.replace(/_/g, " ")}.`,
        entryIds,
        reminder.strength,
        ["homepage", "reminders"],
      ),
    );
  }

  const depth = buildContinuityDepthReport(sorted, { context: "memory", record: false });
  if (depth.indicator) {
    items.push(
      lineToItem(
        depth.indicator.id,
        "continuity_depth",
        depth.indicator.text,
        sorted,
        `Continuity depth kind: ${depth.indicator.kind.replace(/_/g, " ")}.`,
        [],
        depth.indicator.strength,
        ["homepage", "memory"],
      ),
    );
  }

  const familiarity = buildFamiliarityReport(sorted, { context: "memory", limit: 8 });
  for (const note of familiarity.notes) {
    items.push(
      noteToItem(
        {
          id: note.id,
          text: note.text,
          category: "returned",
          confidence: note.strength,
          pastQuote: note.pastQuote,
          currentQuote: note.currentQuote,
          pastEntryId: note.pastEntryId,
          entryId: note.entryId,
        },
        "familiarity",
        sorted,
        "Familiarity note — recurring phrasing or topic feels known in the archive.",
      ),
    );
  }

  const famResurface = buildFamiliarityResurfacingReport(sorted, {
    context: "memory",
    limit: 8,
  });
  for (const note of famResurface.notes) {
    items.push(
      noteToItem(
        {
          id: note.id,
          text: note.text,
          category: "returned",
          confidence: note.strength,
          pastQuote: note.pastQuote,
          currentQuote: note.currentQuote,
          pastEntryId: note.pastEntryId,
          entryId: note.entryId,
        },
        "familiarity_resurfacing",
        sorted,
        "Familiar topic or phrase returned after a gap with recognizable language.",
      ),
    );
  }

  const rhythm = buildRhythmReport(sorted, { context: "memory", limit: 6 });
  for (const note of rhythm.notes) {
    items.push(
      noteToItem(
        {
          id: note.id,
          text: note.text,
          category: "changed",
          confidence: note.strength,
          pastEntryId: note.pastEntryId,
          entryId: note.entryId,
        },
        "rhythm",
        sorted,
        "Rhythm memory — timing or cadence pattern across reflections.",
      ),
    );
  }

  const timeMemory = buildTimeMemoryReport(sorted, { context: "timeline", limit: 6 });
  for (const note of timeMemory.notes) {
    items.push(
      noteToItem(
        {
          id: note.id,
          text: note.text,
          category: "changed",
          confidence: note.strength,
          pastEntryId: note.pastEntryId,
          entryId: note.entryId,
        },
        "time_memory",
        sorted,
        "Time memory — distance-aware note about how an older reflection reads now.",
      ),
    );
  }

  if (sorted.length >= 2) {
    const entryNotes = buildMemoryNotesReport(sorted, {
      context: "entry",
      entryId: latest.id,
      maxTotal: 8,
    });
    for (const note of entryNotes.all) {
      items.push(
        noteToItem(
          note,
          note.id.startsWith("tvn-") ? "then_vs_now" : "memory_callback",
          sorted,
          `Surfaced on latest entry (${latest.id.slice(0, 8)}…).`,
          ["entry"],
        ),
      );
    }
  }

  const deduped = dedupeItems(items).sort(
    (a, b) => b.emotionalWeight - a.emotionalWeight || b.confidence - a.confidence,
  );

  const rewriteCandidateCount = deduped.filter((item) => item.rewriteFlags.length > 0).length;

  return {
    items: deduped,
    rewriteCandidateCount,
    labeledCount: countLabeledCallbacks(),
    hasData: deduped.length > 0,
  };
}
