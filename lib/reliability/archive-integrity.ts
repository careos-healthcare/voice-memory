import { inspectEntryIntegrity } from "@/lib/reliability/integrity";
import type { JournalEntry } from "@/types/journal";
import type { VoiceMemoryArchivePackage } from "@/types/archive-permanence";
import type { EncryptedPayload } from "@/types/sync";
import type {
  SyncAudioMetadataRecord,
  SyncContinuityModel,
} from "@/types/sync-continuity";
import { SYNC_SCHEMA_VERSION } from "@/types/sync-continuity";
import { isSyncContinuityModel } from "@/lib/sync/merge-strategy";

export interface ArchiveIntegrityIssue {
  type:
    | "invalid_model_shape"
    | "missing_entry_fields"
    | "duplicate_entry_id"
    | "missing_audio_metadata"
    | "orphan_audio_metadata"
    | "invalid_archive_package"
    | "corrupted_payload";
  detail: string;
  entryId?: string;
}

export function validateSyncContinuityModel(
  model: unknown,
): { valid: boolean; issues: ArchiveIntegrityIssue[] } {
  const issues: ArchiveIntegrityIssue[] = [];

  if (!isSyncContinuityModel(model)) {
    return {
      valid: false,
      issues: [{ type: "invalid_model_shape", detail: "Payload is not a sync continuity model." }],
    };
  }

  const typed = model as SyncContinuityModel;
  const entries = typed.entries.map((row) => row.entry);
  const seenIds = new Set<string>();

  for (const entry of entries) {
    if (seenIds.has(entry.id)) {
      issues.push({
        type: "duplicate_entry_id",
        entryId: entry.id,
        detail: "Duplicate entry id in sync model.",
      });
    }
    seenIds.add(entry.id);

    if (!entry.transcript || typeof entry.transcript !== "string") {
      issues.push({
        type: "missing_entry_fields",
        entryId: entry.id,
        detail: "Entry missing transcript.",
      });
    }
  }

  const entryIdsWithAudio = new Set(
    entries.filter((entry) => entry.audioId).map((entry) => entry.id),
  );
  const metadataByEntry = new Map(
    typed.audioMetadata.map((row) => [row.entryId, row]),
  );

  for (const entryId of entryIdsWithAudio) {
    if (!metadataByEntry.has(entryId)) {
      issues.push({
        type: "missing_audio_metadata",
        entryId,
        detail: "Entry has audio but no sync audio metadata.",
      });
    }
  }

  for (const row of typed.audioMetadata) {
    if (!entryIdsWithAudio.has(row.entryId)) {
      issues.push({
        type: "orphan_audio_metadata",
        entryId: row.entryId,
        detail: "Audio metadata without matching entry audio reference.",
      });
    }
  }

  return { valid: issues.length === 0, issues };
}

export function crossCheckAudioMetadata(
  model: SyncContinuityModel,
  localAudioIds: Set<string>,
): ArchiveIntegrityIssue[] {
  const issues: ArchiveIntegrityIssue[] = [];

  for (const row of model.audioMetadata) {
    const entry = model.entries.find((record) => record.entry.id === row.entryId)?.entry;
    if (!entry?.audioId) continue;

    if (!localAudioIds.has(entry.audioId)) {
      issues.push({
        type: "missing_audio_metadata",
        entryId: row.entryId,
        detail: "Local audio blob missing for synced metadata — text can still restore.",
      });
    }
  }

  return issues;
}

export function inspectArchivePackageIntegrity(
  archive: VoiceMemoryArchivePackage,
): ArchiveIntegrityIssue[] {
  const issues: ArchiveIntegrityIssue[] = [];

  if (!archive.entries?.length) {
    issues.push({
      type: "invalid_archive_package",
      detail: "Archive package has no entries.",
    });
    return issues;
  }

  const audioIds = new Set(
    archive.audio?.map((file) => file.entryId) ?? [],
  );
  const entryIssues = inspectEntryIntegrity(archive.entries, audioIds);

  for (const issue of entryIssues) {
    issues.push({
      type: "missing_entry_fields",
      entryId: issue.entryId,
      detail: issue.detail,
    });
  }

  return issues;
}

export function isCorruptedEncryptedPayload(payload: EncryptedPayload | null | undefined): boolean {
  if (!payload) return true;
  if (payload.version !== 1) return true;
  if (!payload.ciphertext || !payload.iv) return true;
  if (typeof payload.ciphertext !== "string" || typeof payload.iv !== "string") return true;
  return false;
}

export function schemaVersionFromModel(model: SyncContinuityModel): number {
  return model.envelope?.schemaVersion ?? 0;
}

export function isOlderSchemaModel(model: unknown): boolean {
  if (!model || typeof model !== "object") return false;
  const envelope = (model as SyncContinuityModel).envelope;
  if (!envelope) return true;
  return envelope.schemaVersion < SYNC_SCHEMA_VERSION;
}

export function summarizeEntryIntegrity(entries: JournalEntry[]): {
  duplicateIds: number;
  missingTranscripts: number;
} {
  const seen = new Map<string, number>();
  let missingTranscripts = 0;

  for (const entry of entries) {
    seen.set(entry.id, (seen.get(entry.id) ?? 0) + 1);
    if (typeof entry.transcript !== "string") missingTranscripts += 1;
  }

  const duplicateIds = [...seen.values()].filter((count) => count > 1).length;
  return { duplicateIds, missingTranscripts };
}
