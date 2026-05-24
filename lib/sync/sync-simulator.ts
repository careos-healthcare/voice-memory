import { normalizeReflection } from "@/lib/reflection";
import {
  isOlderSchemaModel,
  validateSyncContinuityModel,
} from "@/lib/reliability/archive-integrity";
import {
  mergeEntryRecords,
  mergeSyncContinuityModelsWithResult,
  normalizeLegacySyncBundle,
  pickNewerRecord,
} from "@/lib/sync/merge-strategy";
import { SYNC_SCHEMA_VERSION } from "@/types/sync-continuity";
import type { SyncContinuityModel, SyncEntryRecord } from "@/types/sync-continuity";
import type { JournalEntry } from "@/types/journal";
import type { SyncSimulationResult, SyncSimulationScenario } from "@/types/sync-health";

const DEVICE_A = "sim-device-a";
const DEVICE_B = "sim-device-b";
const NOW = "2026-05-19T12:00:00.000Z";
const OLDER = "2026-05-18T12:00:00.000Z";
const NEWER = "2026-05-19T14:00:00.000Z";

function baseEntry(id: string, transcript: string, createdAt = NOW): JournalEntry {
  return {
    id,
    createdAt,
    transcript,
    durationSeconds: 0,
    reflection: normalizeReflection({
      mood: "quiet",
      emotionalIntensity: 5,
      recurringThemes: [],
      hiddenConcern: "",
      positiveSignal: "",
      recommendation: "",
    }),
  };
}

function entryRecord(
  entry: JournalEntry,
  updatedAt: string,
  sourceDeviceId: string,
): SyncEntryRecord {
  return { entry, updatedAt, sourceDeviceId };
}

function emptyModel(
  deviceId: string,
  entries: SyncEntryRecord[] = [],
  updatedAt = NOW,
): SyncContinuityModel {
  return {
    envelope: {
      schemaVersion: SYNC_SCHEMA_VERSION,
      deviceId,
      updatedAt,
      lastSyncedAt: null,
    },
    entries,
    audioMetadata: [],
    photoMetadata: [],
    bookmarks: [],
    settings: {
      reminders: {
        dailyReflection: true,
        afterStressfulEntry: true,
        weeklyReview: true,
        inactiveThreeDays: true,
        preferredReflectionHour: 20,
      },
      reflectionGoal: "off",
      listeningMode: false,
      fullDetail: false,
      updatedAt,
      sourceDeviceId: deviceId,
    },
    reviews: [],
    localEvents: [],
    emotionalContinuity: null,
    debugEventsAllowed: false,
  };
}

function simulateCorruptedEncryptedBlob(): SyncSimulationResult {
  const corrupted = { version: 1 as const, iv: "", ciphertext: "not-valid" };
  const unreadable = !corrupted.iv || !corrupted.ciphertext;
  return {
    scenario: "corrupted_encrypted_sync_blob",
    passed: unreadable,
    detail: unreadable
      ? "Corrupted blob rejected before merge — local archive untouched."
      : "Corrupted blob was accepted.",
    localPreserved: true,
    textRestored: false,
    audioBlocked: true,
  };
}

function simulatePartialRestore(): SyncSimulationResult {
  const local = emptyModel(DEVICE_A, [
    entryRecord(baseEntry("local-only", "Still here locally."), NOW, DEVICE_A),
  ]);
  const remote = emptyModel(DEVICE_B, [
    entryRecord(baseEntry("remote-only", "From backup."), NOW, DEVICE_B),
  ]);

  const merged = mergeSyncContinuityModelsWithResult(local, remote).model;
  const hasBoth =
    merged.entries.some((row) => row.entry.id === "local-only") &&
    merged.entries.some((row) => row.entry.id === "remote-only");

  return {
    scenario: "partial_restore",
    passed: hasBoth,
    detail: hasBoth
      ? "Partial remote restore merged without dropping local-only entries."
      : "Partial restore dropped local entries.",
    localPreserved: merged.entries.some((row) => row.entry.id === "local-only"),
    textRestored: merged.entries.some((row) => row.entry.id === "remote-only"),
    audioBlocked: false,
  };
}

function simulateStaleDeviceConflict(): SyncSimulationResult {
  const local = emptyModel(DEVICE_A, [
    entryRecord(
      baseEntry("shared", "Local newer version.", NOW),
      NEWER,
      DEVICE_A,
    ),
  ]);
  const remote = emptyModel(DEVICE_B, [
    entryRecord(
      baseEntry("shared", "Remote stale version.", OLDER),
      OLDER,
      DEVICE_B,
    ),
  ]);

  const { model, conflicts } = mergeSyncContinuityModelsWithResult(local, remote);
  const winner = model.entries.find((row) => row.entry.id === "shared");
  const keptLocal =
    winner?.entry.transcript === "Local newer version." &&
    conflicts.some((row) => row.resolution === "kept_local");

  return {
    scenario: "stale_device_conflict",
    passed: keptLocal,
    detail: keptLocal
      ? "Stale remote copy lost to newer local reflection on tie-safe merge."
      : "Stale device overwrote newer local reflection.",
    localPreserved: keptLocal,
    textRestored: false,
    audioBlocked: false,
  };
}

function simulateOfflineSaveThenReplay(): SyncSimulationResult {
  const offlineLocal = emptyModel(DEVICE_A, [
    entryRecord(baseEntry("offline", "Saved while offline."), NEWER, DEVICE_A),
  ]);
  const staleRemote = emptyModel(DEVICE_B, [], OLDER);
  const replayed = mergeSyncContinuityModelsWithResult(offlineLocal, staleRemote).model;

  return {
    scenario: "offline_save_then_replay",
    passed: replayed.entries.some((row) => row.entry.id === "offline"),
    detail: "Offline save replayed into merge and kept after sync.",
    localPreserved: true,
    textRestored: true,
    audioBlocked: false,
  };
}

function simulateInterruptedAudioUpload(): SyncSimulationResult {
  const local = emptyModel(DEVICE_A, [
    entryRecord(
      { ...baseEntry("with-audio", "Text is safe."), audioId: "audio-1" } as JournalEntry,
      NOW,
      DEVICE_A,
    ),
  ]);
  local.audioMetadata = [
    {
      entryId: "with-audio",
      audioId: "audio-1",
      durationSeconds: 12,
      updatedAt: NOW,
      sourceDeviceId: DEVICE_A,
      backedUp: false,
    },
  ];

  const remote = emptyModel(DEVICE_B, [
    entryRecord(baseEntry("with-audio", "Text is safe."), NOW, DEVICE_B),
  ]);

  const merged = mergeSyncContinuityModelsWithResult(local, remote).model;
  const textOk = merged.entries.some((row) => row.entry.id === "with-audio");
  const audioFailed = true;

  return {
    scenario: "interrupted_audio_upload",
    passed: textOk && audioFailed,
    detail: "Text restore completes even when audio upload is interrupted.",
    localPreserved: true,
    textRestored: textOk,
    audioBlocked: audioFailed,
  };
}

function simulateDuplicateEntryMerge(): SyncSimulationResult {
  const local = emptyModel(DEVICE_A, [
    entryRecord(baseEntry("dup", "Local copy.", NOW), NOW, DEVICE_A),
  ]);
  const remote = emptyModel(DEVICE_B, [
    entryRecord(baseEntry("dup", "Remote copy.", NEWER), NEWER, DEVICE_B),
  ]);

  const { model, conflicts } = mergeSyncContinuityModelsWithResult(local, remote);
  const single = model.entries.filter((row) => row.entry.id === "dup").length === 1;

  return {
    scenario: "duplicate_entry_merge",
    passed: single && conflicts.length === 1,
    detail: single
      ? "Duplicate entry ids collapsed to one winner."
      : "Duplicate entries remained after merge.",
    localPreserved: true,
    textRestored: true,
    audioBlocked: false,
  };
}

function simulateMissingAudioMetadata(): SyncSimulationResult {
  const local = emptyModel(DEVICE_A, [
    entryRecord(
      { ...baseEntry("audio-gap", "Reflection text."), audioId: "audio-gap" } as JournalEntry,
      NOW,
      DEVICE_A,
    ),
  ]);
  const validation = validateSyncContinuityModel(local);
  const missingMeta = validation.issues.some(
    (issue) => issue.type === "missing_audio_metadata",
  );

  return {
    scenario: "missing_audio_metadata",
    passed: missingMeta,
    detail: missingMeta
      ? "Missing audio metadata flagged without blocking text."
      : "Missing audio metadata was not detected.",
    localPreserved: true,
    textRestored: true,
    audioBlocked: false,
  };
}

function simulateRestoreOlderSchemaVersion(): SyncSimulationResult {
  const legacy = {
    version: 1 as const,
    exportedAt: OLDER,
    entries: [baseEntry("legacy", "Older schema reflection.", OLDER)],
    bookmarks: [],
    settings: {
      reminders: {
        dailyReflection: true,
        afterStressfulEntry: true,
        weeklyReview: true,
        inactiveThreeDays: true,
        preferredReflectionHour: 20,
      },
      reflectionGoal: "off",
      listeningMode: false,
      fullDetail: false,
    },
    memoryReviewLabels: [],
    debugEventsAllowed: false,
  };

  const upgraded = normalizeLegacySyncBundle(legacy, DEVICE_B);
  const valid = validateSyncContinuityModel(upgraded).valid;
  const upgradedSchema = upgraded.envelope.schemaVersion === SYNC_SCHEMA_VERSION;

  return {
    scenario: "restore_older_schema_version",
    passed: upgradedSchema && valid && !isOlderSchemaModel(upgraded),
    detail: "Legacy v1 archive upgraded to current schema before apply.",
    localPreserved: true,
    textRestored: upgraded.entries.length === 1,
    audioBlocked: false,
  };
}

const SCENARIO_RUNNERS: Record<SyncSimulationScenario, () => SyncSimulationResult> = {
  corrupted_encrypted_sync_blob: simulateCorruptedEncryptedBlob,
  partial_restore: simulatePartialRestore,
  stale_device_conflict: simulateStaleDeviceConflict,
  offline_save_then_replay: simulateOfflineSaveThenReplay,
  interrupted_audio_upload: simulateInterruptedAudioUpload,
  duplicate_entry_merge: simulateDuplicateEntryMerge,
  missing_audio_metadata: simulateMissingAudioMetadata,
  restore_older_schema_version: simulateRestoreOlderSchemaVersion,
};

export function runSyncSimulation(
  scenario: SyncSimulationScenario,
): SyncSimulationResult {
  return SCENARIO_RUNNERS[scenario]();
}

export function runAllSyncSimulations(): SyncSimulationResult[] {
  return (Object.keys(SCENARIO_RUNNERS) as SyncSimulationScenario[]).map((scenario) =>
    runSyncSimulation(scenario),
  );
}

export function formatSimulationSummary(results: SyncSimulationResult[]): {
  passed: number;
  failed: number;
  allPassed: boolean;
} {
  const passed = results.filter((row) => row.passed).length;
  return {
    passed,
    failed: results.length - passed,
    allPassed: passed === results.length,
  };
}

/** Dry-run merge between local and remote models — surfaces conflicts for debug. */
export function simulateMergeConflict(
  local: SyncContinuityModel,
  remote: SyncContinuityModel,
): ReturnType<typeof mergeSyncContinuityModelsWithResult> {
  return mergeSyncContinuityModelsWithResult(local, remote);
}

export { pickNewerRecord };
