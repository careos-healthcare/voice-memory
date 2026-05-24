import { getPrimaryObservation } from "@/lib/observation-language";
import { formatEntryDate } from "@/lib/utils";
import type { ReflectionBookmark } from "@/types/reflection-bookmark";
import type { JournalEntry } from "@/types/journal";
import type { VoiceMemoryArchivePackage } from "@/types/archive-permanence";

function bookmarkLabel(type: ReflectionBookmark["type"]): string {
  switch (type) {
    case "mattered":
      return "Mattered";
    case "revisit_later":
      return "Revisit later";
    case "changed_something":
      return "Changed something";
  }
}

/** Readable Markdown export for long-term keeping outside the app. */
export function buildArchiveMarkdown(archive: VoiceMemoryArchivePackage): string {
  const lines: string[] = [
    "# VoiceMemory Archive",
    "",
    `Exported: ${formatEntryDate(archive.exportedAt)}`,
    `Reflections: ${archive.entries.length}`,
    "",
    "Reflective mirror only — not therapy or diagnosis.",
    "",
    "---",
    "",
  ];

  if (archive.bookmarks.length > 0) {
    lines.push("## Bookmarks", "");
    for (const bookmark of archive.bookmarks) {
      lines.push(
        `- **${bookmarkLabel(bookmark.type)}** · ${formatEntryDate(bookmark.markedAt)} · entry \`${bookmark.entryId.slice(0, 8)}…\``,
      );
    }
    lines.push("", "---", "");
  }

  lines.push("## Reflections", "");

  const sorted = [...archive.entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );

  for (const entry of sorted) {
    const observation = getPrimaryObservation(entry.reflection);
    lines.push(`### ${formatEntryDate(entry.createdAt)}`);
    lines.push("");
    lines.push(`**Mood:** ${entry.reflection.mood} · **Intensity:** ${entry.reflection.emotionalIntensity}/10`);
    if (entry.reflection.recurringThemes.length > 0) {
      lines.push(`**Themes:** ${entry.reflection.recurringThemes.join(", ")}`);
    }
    lines.push("");
    if (entry.transcript.trim()) {
      lines.push("**Transcript**");
      lines.push("");
      lines.push(entry.transcript.trim());
      lines.push("");
    }
    if (observation) {
      lines.push("**Observation**");
      lines.push("");
      lines.push(observation);
      lines.push("");
    }
    lines.push("---");
    lines.push("");
  }

  return lines.join("\n").trimEnd() + "\n";
}
