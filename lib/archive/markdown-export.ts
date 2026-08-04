import { EXPORT_TRUST_FOOTER } from "@/lib/product-copy";
import { getPrimaryObservation } from "@/lib/observation-language";
import { formatEntryDate } from "@/lib/utils";
import type { ReflectionBookmark } from "@/types/reflection-bookmark";
import type { JournalEntry } from "@/types/journal";
import type { ArchiveMeArchivePackage } from "@/types/archive-permanence";

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
export function buildArchiveMarkdown(archive: ArchiveMeArchivePackage): string {
  const lines: string[] = [
    "# ArchiveMe Archive",
    "",
    `Exported: ${formatEntryDate(archive.exportedAt)}`,
    `Saved moments: ${archive.entries.length}`,
    "",
    EXPORT_TRUST_FOOTER,
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

  lines.push("## Saved moments", "");

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
    if (entry.rawTranscript?.trim() && entry.rawTranscript.trim() !== entry.transcript.trim()) {
      lines.push("**Original transcript (before cleanup)**");
      lines.push("");
      lines.push(entry.rawTranscript.trim());
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
