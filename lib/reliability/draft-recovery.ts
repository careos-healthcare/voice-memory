import { createListeningModeEntry } from "@/lib/pending-reflection";
import {
  prepareTranscriptForSave,
  trackTranscriptCleanupEvents,
} from "@/lib/transcript/transcript-cleanup";
import { safeGetJson, safeSetJson } from "@/lib/reliability/safe-local-storage";
import { saveEntry } from "@/lib/storage";
import type { JournalEntry, Reflection } from "@/types/journal";
import type { RecoveryDraft } from "@/types/storage-reliability";

const DRAFTS_KEY = "voicememory_recovery_drafts";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readDrafts(): RecoveryDraft[] {
  if (!isBrowser()) return [];

  const parsed = safeGetJson<RecoveryDraft[]>(DRAFTS_KEY);
  if (!Array.isArray(parsed)) return [];

  return parsed.filter(
    (draft) =>
      draft?.version === 1 &&
      typeof draft.id === "string" &&
      typeof draft.transcript === "string" &&
      draft.transcript.trim().length > 0,
  );
}

function writeDrafts(drafts: RecoveryDraft[]): void {
  if (!isBrowser()) return;
  safeSetJson(DRAFTS_KEY, drafts);
}

export function listRecoveryDrafts(): RecoveryDraft[] {
  return readDrafts();
}

export function saveRecoveryDraft(
  draft: Omit<RecoveryDraft, "version" | "createdAt"> & { createdAt?: string },
): RecoveryDraft {
  const full: RecoveryDraft = {
    version: 1,
    createdAt: draft.createdAt ?? new Date().toISOString(),
    ...draft,
  };

  const drafts = readDrafts().filter((item) => item.id !== full.id);
  drafts.unshift(full);
  writeDrafts(drafts.slice(0, 8));
  return full;
}

export function removeRecoveryDraft(id: string): void {
  writeDrafts(readDrafts().filter((draft) => draft.id !== id));
}

export function clearRecoveryDrafts(): number {
  const count = readDrafts().length;
  if (isBrowser()) {
    localStorage.removeItem(DRAFTS_KEY);
  }
  return count;
}

function draftToEntry(draft: RecoveryDraft): JournalEntry {
  if (draft.reflection && draft.reflectionPending !== true) {
    return {
      id: draft.id,
      createdAt: draft.createdAt,
      transcript: draft.transcript,
      reflection: draft.reflection,
      durationSeconds: draft.durationSeconds,
      audioId: draft.audioId,
      reflectionPending: false,
    };
  }

  return createListeningModeEntry(
    draft.id,
    draft.transcript,
    draft.durationSeconds,
    draft.audioId,
  );
}

/** Promote stored drafts into journal entries. Returns count recovered. */
export function recoverPendingDrafts(): { recovered: number; entryIds: string[] } {
  const drafts = readDrafts();
  if (drafts.length === 0) {
    return { recovered: 0, entryIds: [] };
  }

  const entryIds: string[] = [];

  for (const draft of drafts) {
    const entry = draftToEntry(draft);
    saveEntry(entry);
    entryIds.push(entry.id);
  }

  clearRecoveryDrafts();
  return { recovered: drafts.length, entryIds };
}

export function persistTranscriptDraft(
  transcript: string,
  durationSeconds: number,
  options?: {
    id?: string;
    audioId?: string;
    reflection?: Reflection | null;
    reason?: RecoveryDraft["reason"];
  },
): JournalEntry {
  const entryId = options?.id ?? crypto.randomUUID();
  const reason = options?.reason ?? "analysis_failed";
  const prepared = prepareTranscriptForSave(transcript);

  saveRecoveryDraft({
    id: entryId,
    transcript: prepared.transcript,
    durationSeconds,
    reflectionPending: !options?.reflection,
    reflection: options?.reflection ?? null,
    audioId: options?.audioId,
    reason,
  });

  const entry = options?.reflection
    ? {
        id: entryId,
        createdAt: new Date().toISOString(),
        transcript: prepared.transcript,
        rawTranscript: prepared.rawTranscript,
        transcriptCleanup: prepared.transcriptCleanup,
        reflection: options.reflection,
        durationSeconds,
        audioId: options?.audioId,
      }
    : {
        ...createListeningModeEntry(
          entryId,
          prepared.transcript,
          durationSeconds,
          options?.audioId,
        ),
        rawTranscript: prepared.rawTranscript,
        transcriptCleanup: prepared.transcriptCleanup,
      };

  trackTranscriptCleanupEvents(prepared.result, entryId);
  saveEntry(entry);
  removeRecoveryDraft(entryId);
  return entry;
}
