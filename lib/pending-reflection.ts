import { normalizeReflection } from "@/lib/reflection";
import { formatEntryDate } from "@/lib/utils";
import { getAllEntries, getEntry, saveEntry } from "@/lib/storage";
import type { JournalEntry, Reflection } from "@/types/journal";

export function createPendingReflection(): Reflection {
  return normalizeReflection({
    mood: "quiet",
    emotionalIntensity: 5,
    recurringThemes: [],
    hiddenConcern: "",
    positiveSignal: "",
    recommendation: "",
  });
}

export function isReflectionPending(entry: JournalEntry): boolean {
  return entry.reflectionPending === true;
}

export function createListeningModeEntry(
  entryId: string,
  transcript: string,
  durationSeconds: number,
  audioId?: string,
): JournalEntry {
  return {
    id: entryId,
    createdAt: new Date().toISOString(),
    transcript,
    reflection: createPendingReflection(),
    durationSeconds,
    audioId,
    reflectionPending: true,
  };
}

/** Generate reflection for a listening-mode entry saved without interpretation. */
export async function generateReflectionForEntry(
  entryId: string,
): Promise<JournalEntry> {
  const entry = getEntry(entryId);
  if (!entry) {
    throw new Error("Entry not found");
  }
  if (!isReflectionPending(entry)) {
    return entry;
  }

  const priorContext = getAllEntries()
    .filter((e) => e.id !== entryId && !isReflectionPending(e))
    .slice(0, 5)
    .map((e) => ({
      date: formatEntryDate(e.createdAt),
      excerpt: e.transcript.slice(0, 300),
      themes: e.reflection.recurringThemes,
    }));

  const analyzeResponse = await fetch("/api/analyze", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ transcript: entry.transcript, priorContext }),
  });

  const analyzeData = (await analyzeResponse.json()) as {
    reflection?: Reflection;
    error?: string;
  };

  if (!analyzeResponse.ok || !analyzeData.reflection) {
    throw new Error(analyzeData.error ?? "Could not reflect on this entry");
  }

  const updated: JournalEntry = {
    ...entry,
    reflection: analyzeData.reflection,
    reflectionPending: false,
  };

  saveEntry(updated);
  return updated;
}
