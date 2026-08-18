import { captureAuthHeaders, ensureCaptureAttested } from "@/lib/client/capture-attest";
import { buildPriorEvidenceRefs } from "@/lib/evidence/prior-evidence-client";
import { normalizeReflection } from "@/lib/reflection";
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

  // Prompt Context Contract: entry references only, no raw text.
  const priorEvidence = buildPriorEvidenceRefs(
    getAllEntries().filter((e) => !isReflectionPending(e)),
    entryId,
  );

  const attested = await ensureCaptureAttested();
  if (!attested) {
    throw new Error("Device attestation required before analysis.");
  }

  const analyzeResponse = await fetch("/api/analyze", {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
      ...captureAuthHeaders(),
    },
    body: JSON.stringify({ transcript: entry.transcript, priorEvidence }),
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
