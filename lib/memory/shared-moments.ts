import { entryChangeMomentsNotes } from "@/lib/memory/change-moments";
import { entryMemoryNotes } from "@/lib/patterns/memory-notes";
import type { EmotionalMilestone, EmotionalMilestoneKind } from "@/types/emotional-milestone";
import type { JournalEntry } from "@/types/journal";
import type {
  SharedMemoryMomentCopyExample,
  SharedMemoryMomentTemplate,
} from "@/types/shared-memory-moment";

export const SHARED_MOMENT_COPY: Record<SharedMemoryMomentTemplate, string> = {
  forgot_sound: "I forgot I used to sound like this.",
  quieter_thought: "This was a quieter version of the same thought.",
  changed_over_time: "This changed over time.",
};

export const SHARED_MEMORY_MOMENT_COPY_EXAMPLES: SharedMemoryMomentCopyExample[] = [
  { template: "forgot_sound", message: SHARED_MOMENT_COPY.forgot_sound },
  { template: "quieter_thought", message: SHARED_MOMENT_COPY.quieter_thought },
  { template: "changed_over_time", message: SHARED_MOMENT_COPY.changed_over_time },
];

const QUOTE_MAX = 140;

const MILESTONE_TEMPLATE: Record<EmotionalMilestoneKind, SharedMemoryMomentTemplate> = {
  first_calmer_topic: "quieter_thought",
  recovery_after_loop: "quieter_thought",
  direct_naming: "changed_over_time",
  topic_absent_after_intensity: "forgot_sound",
  phrase_disappeared: "forgot_sound",
};

export interface BuildSharedMemoryMomentOptions {
  includeQuote?: boolean;
}

function quoteFromEntry(entry: JournalEntry | undefined): string | null {
  if (!entry) return null;

  const pattern = entry.reflection.exactLanguagePattern?.trim();
  if (pattern) {
    return pattern.length > QUOTE_MAX ? `${pattern.slice(0, QUOTE_MAX)}…` : pattern;
  }

  const transcript = entry.transcript?.trim();
  if (!transcript) return null;

  const sentence = transcript.split(/(?<=[.!?])\s+/)[0]?.trim() ?? transcript;
  const excerpt = sentence.length > QUOTE_MAX ? `${sentence.slice(0, QUOTE_MAX)}…` : sentence;
  return excerpt;
}

function entryTemplate(
  entry: JournalEntry,
  allEntries: JournalEntry[],
): SharedMemoryMomentTemplate {
  const notes = entryMemoryNotes(allEntries, entry.id);
  const changeMoments = entryChangeMomentsNotes(allEntries, entry.id, 2);

  if (notes?.thenVsNow?.length) {
    const soundShift = notes.thenVsNow.some((note) =>
      /\b(sound|word|phrase|said|talk|language|voice)\b/i.test(note.text),
    );
    if (soundShift) return "forgot_sound";
    return "changed_over_time";
  }

  const calmer = changeMoments.some((note) =>
    /\b(calm|quiet|softer|gentler|less tense|eased)\b/i.test(note.text),
  );
  if (calmer) return "quieter_thought";

  if (notes?.primaryCallback?.category === "faded") return "forgot_sound";
  if (notes?.primaryCallback?.category === "changed") return "changed_over_time";

  return "changed_over_time";
}

function milestoneTemplate(kind: EmotionalMilestoneKind): SharedMemoryMomentTemplate {
  return MILESTONE_TEMPLATE[kind] ?? "changed_over_time";
}

function resolveMilestoneEntry(
  milestone: EmotionalMilestone,
  allEntries: JournalEntry[],
): JournalEntry | undefined {
  const id = milestone.entryId ?? milestone.pastEntryId;
  if (!id) return undefined;
  return allEntries.find((entry) => entry.id === id);
}

export function buildEntrySharedMemoryMoment(
  entry: JournalEntry,
  allEntries: JournalEntry[],
  options: BuildSharedMemoryMomentOptions = {},
): string {
  const template = entryTemplate(entry, allEntries);
  return assembleMomentText(template, quoteFromEntry(entry), options.includeQuote);
}

export function buildMilestoneSharedMemoryMoment(
  milestone: EmotionalMilestone,
  allEntries: JournalEntry[],
  options: BuildSharedMemoryMomentOptions = {},
): string {
  const template = milestoneTemplate(milestone.kind);
  const quoteEntry = resolveMilestoneEntry(milestone, allEntries);
  return assembleMomentText(template, quoteFromEntry(quoteEntry), options.includeQuote);
}

function assembleMomentText(
  template: SharedMemoryMomentTemplate,
  quote: string | null,
  includeQuote?: boolean,
): string {
  const lines = [SHARED_MOMENT_COPY[template]];
  if (includeQuote && quote) {
    lines.push(`"${quote}"`);
  }
  return lines.join("\n\n");
}
