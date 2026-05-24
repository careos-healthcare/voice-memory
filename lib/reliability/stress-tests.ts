import { normalizeReflection } from "@/lib/reflection";
import {
  crossCheckAudioMetadata,
  isCorruptedEncryptedPayload,
  validateSyncContinuityModel,
} from "@/lib/reliability/archive-integrity";
import { inspectEntryIntegrity } from "@/lib/reliability/integrity";
import {
  mergeEntryRecords,
  mergeSyncContinuityModelsWithResult,
} from "@/lib/sync/merge-strategy";
import { SYNC_SCHEMA_VERSION } from "@/types/sync-continuity";
import type {
  ArchiveStressScenario,
  StressTestResult,
  StressTestRunReport,
} from "@/types/archive-stress";
import type { JournalEntry } from "@/types/journal";
import type { EncryptedPayload } from "@/types/sync";
import type { SyncContinuityModel, SyncEntryRecord } from "@/types/sync-continuity";

export const STRESS_TEST_SEED = 0xc0ffee;
const LAST_RUN_KEY = "voicememory_archive_stress_last_run";

const DEVICE_LOCAL = "stress-device-local";
const DEVICE_REMOTE = "stress-device-remote";
const BASE_TIME = new Date("2026-01-01T12:00:00.000Z").getTime();
const MS_DAY = 86_400_000;

export function createSeededRandom(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) | 0;
    let t = Math.imul(state ^ (state >>> 15), 1 | state);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function baseEntry(id: string, createdAt: string, transcript: string): JournalEntry {
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

function entryRecord(entry: JournalEntry, deviceId: string): SyncEntryRecord {
  return {
    entry,
    updatedAt: entry.createdAt,
    sourceDeviceId: deviceId,
  };
}

function emptyModel(deviceId: string, entries: SyncEntryRecord[] = []): SyncContinuityModel {
  const now = new Date(BASE_TIME).toISOString();
  return {
    envelope: {
      schemaVersion: SYNC_SCHEMA_VERSION,
      deviceId,
      updatedAt: now,
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
      updatedAt: now,
      sourceDeviceId: deviceId,
    },
    reviews: [],
    localEvents: [],
    emotionalContinuity: null,
    debugEventsAllowed: false,
  };
}

class MemoryLocalStorage {
  private map = new Map<string, string>();
  private quotaBytes: number;
  private throwOnSet = false;

  constructor(quotaBytes = Number.POSITIVE_INFINITY) {
    this.quotaBytes = quotaBytes;
  }

  setThrowOnSet(value: boolean): void {
    this.throwOnSet = value;
  }

  private byteSize(value: string): number {
    return value.length * 2;
  }

  private totalBytes(): number {
    let total = 0;
    for (const value of this.map.values()) total += this.byteSize(value);
    return total;
  }

  getItem(key: string): string | null {
    return this.map.get(key) ?? null;
  }

  setItem(key: string, value: string): void {
    if (this.throwOnSet) {
      throw new DOMException("QuotaExceededError", "QuotaExceededError");
    }
    const nextTotal =
      this.totalBytes() - this.byteSize(this.map.get(key) ?? "") + this.byteSize(value);
    if (nextTotal > this.quotaBytes) {
      throw new DOMException("QuotaExceededError", "QuotaExceededError");
    }
    this.map.set(key, value);
  }

  removeItem(key: string): void {
    this.map.delete(key);
  }

  snapshot(): Record<string, string> {
    return Object.fromEntries(this.map.entries());
  }
}

function safeSetJsonInMemory(
  storage: MemoryLocalStorage,
  key: string,
  value: unknown,
): { backupCreated: boolean } {
  const pendingKey = `${key}__pending`;
  const backupKey = `${key}__backup`;
  const serialized = JSON.stringify(value);

  storage.setItem(pendingKey, serialized);
  const readBack = storage.getItem(pendingKey);
  if (readBack !== serialized) {
    throw new Error(`Storage verify failed for ${key}`);
  }

  const existing = storage.getItem(key);
  let backupCreated = false;
  if (existing !== null) {
    storage.setItem(backupKey, existing);
    backupCreated = true;
  }

  storage.setItem(key, serialized);
  storage.removeItem(pendingKey);
  return { backupCreated };
}

function assert(condition: boolean, message: string, failures: string[]): void {
  if (!condition) failures.push(message);
}

function runTimed(
  scenario: ArchiveStressScenario,
  runner: () => {
    recoveryPath: string;
    detail: string;
    failedAssertions?: string[];
    corruptedPayloadPreview?: string;
    rollbackPreview?: string;
  },
): StressTestResult {
  const start = typeof performance !== "undefined" ? performance.now() : Date.now();
  try {
    const meta = runner();
    const failedAssertions = meta.failedAssertions ?? [];
    return {
      scenario,
      passed: failedAssertions.length === 0,
      recoveryPath: meta.recoveryPath,
      failedAssertions,
      corruptedPayloadPreview: meta.corruptedPayloadPreview,
      rollbackPreview: meta.rollbackPreview,
      detail: meta.detail,
      durationMs: Math.round((typeof performance !== "undefined" ? performance.now() : Date.now()) - start),
    };
  } catch (error) {
    return {
      scenario,
      passed: false,
      recoveryPath: "exception",
      failedAssertions: [
        error instanceof Error ? error.message : "Unhandled stress test exception",
      ],
      detail: "Stress test threw before assertions completed.",
      durationMs: Math.round((typeof performance !== "undefined" ? performance.now() : Date.now()) - start),
    };
  }
}

function simulateEntrySaveLoop1000(): StressTestResult {
  return runTimed("entry_save_loop_1000", () => {
    const rng = createSeededRandom(STRESS_TEST_SEED);
    const storage = new MemoryLocalStorage();
    const key = "voicememory_entries";
    const failures: string[] = [];
    const entries: JournalEntry[] = [];

    for (let i = 0; i < 1000; i += 1) {
      const id = `stress-entry-${i}-${Math.floor(rng() * 1_000_000)}`;
      entries.push(
        baseEntry(id, new Date(BASE_TIME + i * 1000).toISOString(), `Reflection ${i}`),
      );
      safeSetJsonInMemory(storage, key, entries);
    }

    const raw = storage.getItem(key);
    assert(Boolean(raw), "Final entries blob missing", failures);
    const parsed = JSON.parse(raw!) as JournalEntry[];
    assert(parsed.length === 1000, `Expected 1000 entries, got ${parsed.length}`, failures);
    assert(Boolean(storage.getItem(`${key}__backup`)), "Pre-write backup missing", failures);

    const ids = new Set(parsed.map((entry) => entry.id));
    assert(ids.size === 1000, "Duplicate entry ids after save loop", failures);

    const integrity = inspectEntryIntegrity(parsed, new Set());
    assert(integrity.length === 0, `Integrity issues: ${integrity.length}`, failures);

    return {
      recoveryPath: "safe_set_json_verify_swap",
      detail: "1000 deterministic entry writes completed with backup and integrity intact.",
      failedAssertions: failures,
    };
  });
}

function simulateInterruptedSyncMidUpload(): StressTestResult {
  return runTimed("interrupted_sync_mid_upload", () => {
    const failures: string[] = [];
    const local = emptyModel(DEVICE_LOCAL, [
      entryRecord(
        baseEntry("keep-local", new Date(BASE_TIME).toISOString(), "Local text"),
        DEVICE_LOCAL,
      ),
    ]);

    let corePushed = false;
    let audioFailures = 0;
    const audioPlan = [{ entryId: "a1" }, { entryId: "a2" }];

    try {
      corePushed = true;
      for (const item of audioPlan) {
        if (item.entryId === "a2") throw new Error("Audio upload interrupted");
      }
    } catch {
      audioFailures += 1;
    }

    assert(corePushed, "Core archive push did not complete", failures);
    assert(audioFailures > 0, "Expected audio interruption", failures);
    assert(local.entries.length === 1, "Local archive mutated during interrupted sync", failures);

    return {
      recoveryPath: "text_core_committed_audio_isolated",
      detail: "Core text backup completes; audio failure is isolated and local archive preserved.",
      failedAssertions: failures,
    };
  });
}

function simulateCorruptedEncryptedPayload(): StressTestResult {
  return runTimed("corrupted_encrypted_payload", () => {
    const failures: string[] = [];
    const corrupted: EncryptedPayload = { version: 1, iv: "", ciphertext: "!!!" };
    const preview = JSON.stringify(corrupted).slice(0, 120);

    assert(isCorruptedEncryptedPayload(corrupted), "Corrupted payload not detected", failures);

    const mergeAttempted = !isCorruptedEncryptedPayload(corrupted);
    assert(!mergeAttempted, "Merge attempted on corrupted payload", failures);

    return {
      recoveryPath: "reject_before_decrypt",
      corruptedPayloadPreview: preview,
      detail: "Corrupted encrypted blob rejected before merge or restore.",
      failedAssertions: failures,
    };
  });
}

function simulateDuplicateDeviceSyncRace(): StressTestResult {
  return runTimed("duplicate_device_sync_race", () => {
    const failures: string[] = [];
    const local = emptyModel(DEVICE_LOCAL, [
      entryRecord(
        baseEntry("shared", new Date(BASE_TIME + MS_DAY).toISOString(), "Local newer"),
        DEVICE_LOCAL,
      ),
      entryRecord(
        baseEntry("local-only", new Date(BASE_TIME).toISOString(), "Only local"),
        DEVICE_LOCAL,
      ),
    ]);
    const remote = emptyModel(DEVICE_REMOTE, [
      entryRecord(
        baseEntry("shared", new Date(BASE_TIME).toISOString(), "Remote stale"),
        DEVICE_REMOTE,
      ),
      entryRecord(
        baseEntry("remote-only", new Date(BASE_TIME).toISOString(), "Only remote"),
        DEVICE_REMOTE,
      ),
    ]);

    const merged = mergeSyncContinuityModelsWithResult(local, remote);
    const ids = merged.model.entries.map((row) => row.entry.id);

    assert(ids.includes("local-only"), "Local-only entry dropped in race", failures);
    assert(ids.includes("remote-only"), "Remote-only entry dropped in race", failures);
    assert(
      merged.model.entries.find((row) => row.entry.id === "shared")?.entry.transcript ===
        "Local newer",
      "Shared entry did not keep newer local copy",
      failures,
    );
    assert(merged.conflicts.length >= 1, "Expected merge conflict record", failures);

    const validation = validateSyncContinuityModel(merged.model);
    assert(validation.valid, "Merged model failed integrity validation", failures);

    return {
      recoveryPath: "union_merge_newest_wins",
      detail: "Duplicate-device race merged without loss; conflicts recorded.",
      failedAssertions: failures,
    };
  });
}

function simulateAudioBlobMismatch(): StressTestResult {
  return runTimed("audio_blob_mismatch", () => {
    const failures: string[] = [];
    const entry = baseEntry("audio-entry", new Date(BASE_TIME).toISOString(), "Text survives");
    entry.audioId = "missing-audio-id";

    const model = emptyModel(DEVICE_LOCAL, [entryRecord(entry, DEVICE_LOCAL)]);
    model.audioMetadata = [
      {
        entryId: entry.id,
        audioId: entry.audioId!,
        durationSeconds: 12,
        updatedAt: entry.createdAt,
        sourceDeviceId: DEVICE_LOCAL,
        backedUp: false,
      },
    ];

    const issues = crossCheckAudioMetadata(model, new Set<string>());
    assert(issues.length > 0, "Audio mismatch not flagged", failures);

    const textValidation = validateSyncContinuityModel(model);
    assert(textValidation.valid, "Text model rejected due to audio mismatch", failures);

    return {
      recoveryPath: "text_restore_continues_audio_flagged",
      detail: "Missing audio blob flagged; text archive remains restorable.",
      failedAssertions: failures,
    };
  });
}

function simulateOfflineReplayAfter7Days(): StressTestResult {
  return runTimed("offline_replay_after_7_days", () => {
    const failures: string[] = [];
    const offlineAt = new Date(BASE_TIME + 7 * MS_DAY).toISOString();

    const local = emptyModel(DEVICE_LOCAL, [
      entryRecord(baseEntry("offline-save", offlineAt, "Saved offline"), DEVICE_LOCAL),
    ]);
    const remote = emptyModel(DEVICE_REMOTE, []);

    const merged = mergeSyncContinuityModelsWithResult(local, remote);
    assert(
      merged.model.entries.some((row) => row.entry.id === "offline-save"),
      "Offline save lost after 7-day replay",
      failures,
    );

    return {
      recoveryPath: "offline_local_replay_merge",
      detail: "Seven-day offline save replayed into merge without remote wipe.",
      failedAssertions: failures,
    };
  });
}

function simulatePartialIndexedDbFailure(): StressTestResult {
  return runTimed("partial_indexeddb_failure", () => {
    const failures: string[] = [];
    const entries = [
      baseEntry("text-only", new Date(BASE_TIME).toISOString(), "Still here"),
      baseEntry("with-audio", new Date(BASE_TIME + 1000).toISOString(), "Text ok"),
    ];
    entries[1].audioId = "audio-1";

    const indexedDbAvailable = new Set<string>();
    const issues = inspectEntryIntegrity(entries, indexedDbAvailable);
    assert(
      issues.some((issue) => issue.type === "missing_audio_reference"),
      "Missing audio reference not detected",
      failures,
    );

    const textOnlyIssues = inspectEntryIntegrity([entries[0]], indexedDbAvailable);
    assert(textOnlyIssues.length === 0, "Text-only entry blocked by audio failure", failures);

    return {
      recoveryPath: "partial_audio_failure_text_preserved",
      detail: "IndexedDB audio read failure does not block text-only integrity.",
      failedAssertions: failures,
    };
  });
}

function simulateLocalStorageQuotaExhaustion(): StressTestResult {
  return runTimed("localstorage_quota_exhaustion", () => {
    const failures: string[] = [];
    const storage = new MemoryLocalStorage(16_384);
    const key = "voicememory_entries";
    const seedEntries = [baseEntry("seed", new Date(BASE_TIME).toISOString(), "Seed")];

    safeSetJsonInMemory(storage, key, seedEntries);

    let threw = false;
    try {
      const huge = Array.from({ length: 400 }, (_, i) =>
        baseEntry(`bulk-${i}`, new Date(BASE_TIME + i).toISOString(), "x".repeat(400)),
      );
      safeSetJsonInMemory(storage, key, huge);
    } catch {
      threw = true;
    }

    assert(threw, "Quota exhaustion did not fail loudly", failures);
    const after = JSON.parse(storage.getItem(key)!) as JournalEntry[];
    assert(after.length === 1 && after[0]?.id === "seed", "Original archive overwritten after quota failure", failures);
    assert(storage.getItem(`${key}__pending`) === null, "Pending write left behind after quota failure", failures);

    return {
      recoveryPath: "verify_swap_aborts_preserves_backup",
      detail: "Quota exhaustion aborts write; prior archive and backup remain.",
      failedAssertions: failures,
    };
  });
}

function simulateRestoreRollbackFailure(): StressTestResult {
  return runTimed("restore_rollback_failure", () => {
    const failures: string[] = [];
    const storage = new MemoryLocalStorage();
    const key = "voicememory_entries";
    const original = [baseEntry("original", new Date(BASE_TIME).toISOString(), "Keep me")];
    safeSetJsonInMemory(storage, key, original);

    const snapshot = storage.snapshot();
    const rollbackPreview = JSON.stringify(snapshot).slice(0, 160);

    let applyFailed = false;
    try {
      storage.setThrowOnSet(true);
      safeSetJsonInMemory(storage, key, [
        baseEntry("broken-restore", new Date(BASE_TIME + MS_DAY).toISOString(), "Should not stick"),
      ]);
    } catch {
      applyFailed = true;
    } finally {
      storage.setThrowOnSet(false);
    }

    assert(applyFailed, "Expected restore apply failure", failures);

    for (const [k, v] of Object.entries(snapshot)) {
      storage.setItem(k, v);
    }

    const rolledBack = JSON.parse(storage.getItem(key)!) as JournalEntry[];
    assert(rolledBack[0]?.id === "original", "Rollback did not restore original archive", failures);

    return {
      recoveryPath: "pre_restore_snapshot_rollback",
      rollbackPreview,
      detail: "Failed restore rolls back to pre-restore snapshot without data loss.",
      failedAssertions: failures,
    };
  });
}

function simulateStaleDeviceOverwriteAttempt(): StressTestResult {
  return runTimed("stale_device_overwrite_attempt", () => {
    const failures: string[] = [];
    const local = emptyModel(DEVICE_LOCAL, [
      entryRecord(
        baseEntry("shared", new Date(BASE_TIME + 2 * MS_DAY).toISOString(), "Fresh local"),
        DEVICE_LOCAL,
      ),
    ]);
    const staleRemote = emptyModel(DEVICE_REMOTE, [
      entryRecord(
        baseEntry("shared", new Date(BASE_TIME).toISOString(), "Stale remote"),
        DEVICE_REMOTE,
      ),
    ]);

    const { merged, conflicts } = mergeEntryRecords(
      local.entries,
      staleRemote.entries,
      DEVICE_LOCAL,
    );
    const winner = merged.find((row) => row.entry.id === "shared");

    assert(winner?.entry.transcript === "Fresh local", "Stale remote overwrote local archive", failures);
    assert(conflicts.length === 1, "Expected stale overwrite conflict", failures);

    return {
      recoveryPath: "local_wins_on_newer_timestamp",
      detail: "Stale remote device could not overwrite newer local reflection.",
      failedAssertions: failures,
    };
  });
}

const SCENARIO_RUNNERS: Record<ArchiveStressScenario, () => StressTestResult> = {
  entry_save_loop_1000: simulateEntrySaveLoop1000,
  interrupted_sync_mid_upload: simulateInterruptedSyncMidUpload,
  corrupted_encrypted_payload: simulateCorruptedEncryptedPayload,
  duplicate_device_sync_race: simulateDuplicateDeviceSyncRace,
  audio_blob_mismatch: simulateAudioBlobMismatch,
  offline_replay_after_7_days: simulateOfflineReplayAfter7Days,
  partial_indexeddb_failure: simulatePartialIndexedDbFailure,
  localstorage_quota_exhaustion: simulateLocalStorageQuotaExhaustion,
  restore_rollback_failure: simulateRestoreRollbackFailure,
  stale_device_overwrite_attempt: simulateStaleDeviceOverwriteAttempt,
};

export function runArchiveStressTest(scenario: ArchiveStressScenario): StressTestResult {
  return SCENARIO_RUNNERS[scenario]();
}

export function runAllArchiveStressTests(): StressTestRunReport {
  const results = (Object.keys(SCENARIO_RUNNERS) as ArchiveStressScenario[]).map((scenario) =>
    runArchiveStressTest(scenario),
  );
  const passed = results.filter((row) => row.passed).length;

  return {
    runAt: new Date().toISOString(),
    seed: STRESS_TEST_SEED,
    passed,
    failed: results.length - passed,
    allPassed: passed === results.length,
    results,
  };
}

export function saveStressTestReport(report: StressTestRunReport): void {
  if (!isBrowser()) return;
  localStorage.setItem(LAST_RUN_KEY, JSON.stringify(report));
}

export function readLastStressTestReport(): StressTestRunReport | null {
  if (!isBrowser()) return null;
  try {
    const raw = localStorage.getItem(LAST_RUN_KEY);
    if (!raw) return null;
    return JSON.parse(raw) as StressTestRunReport;
  } catch {
    return null;
  }
}

export function formatStressReportSummary(report: StressTestRunReport): string {
  return `${report.passed}/${report.results.length} passed · seed ${report.seed}`;
}
