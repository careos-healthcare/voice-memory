import { listAudioEntryIds } from "@/lib/audio-storage";
import { readLastStressTestReport } from "@/lib/reliability/stress-tests";
import { buildStorageHealthReport } from "@/lib/reliability/integrity";
import { hasPreRestoreBackup, readLastRestoreAt } from "@/lib/sync/sync-health";
import { readLastBackupAt, readLastSyncError } from "@/lib/sync/status-storage";
import { readLastSyncedAt } from "@/lib/sync/sync-metadata";
import { getAllEntries } from "@/lib/storage";
import type {
  ProductionReadinessReport,
  ReadinessCheck,
  ReadinessCheckStatus,
} from "@/types/observation-workflow";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function check(status: ReadinessCheckStatus, id: string, label: string, detail: string): ReadinessCheck {
  return { id, label, status, detail };
}

async function probeIndexedDb(): Promise<ReadinessCheck> {
  if (!isBrowser()) {
    return check("unknown", "safari_indexeddb", "Safari IndexedDB support", "Server context.");
  }

  if (typeof indexedDB === "undefined") {
    return check("fail", "safari_indexeddb", "Safari IndexedDB support", "indexedDB unavailable.");
  }

  try {
    await new Promise<void>((resolve, reject) => {
      const request = indexedDB.open("voicememory_readiness_probe", 1);
      request.onerror = () => reject(request.error);
      request.onsuccess = () => {
        request.result.close();
        indexedDB.deleteDatabase("voicememory_readiness_probe");
        resolve();
      };
      request.onupgradeneeded = () => {
        request.result.createObjectStore("probe");
      };
    });
    return check("pass", "safari_indexeddb", "Safari IndexedDB support", "Read/write probe succeeded.");
  } catch (error) {
    return check(
      "fail",
      "safari_indexeddb",
      "Safari IndexedDB support",
      error instanceof Error ? error.message : "IndexedDB probe failed.",
    );
  }
}

function checkMicrophonePermission(): ReadinessCheck {
  if (!isBrowser()) {
    return check("unknown", "ios_microphone", "Microphone permission", "Server context.");
  }

  const ua = navigator.userAgent;
  const isIos = /iPad|iPhone|iPod/.test(ua);
  const hasMedia = typeof navigator.mediaDevices?.getUserMedia === "function";

  if (!hasMedia) {
    return check("fail", "ios_microphone", "Microphone permission", "getUserMedia not available.");
  }

  const canQueryPermission =
    "permissions" in navigator &&
    typeof navigator.permissions?.query === "function";

  if (canQueryPermission) {
    return check(
      "warn",
      "ios_microphone",
      "Microphone permission",
      isIos
        ? "iOS detected — permission granted only after user starts recording."
        : "Permission state requires a user gesture to verify.",
    );
  }

  return check(
    isIos ? "warn" : "pass",
    "ios_microphone",
    "Microphone permission",
    isIos ? "iOS — test recording on device." : "Media API available.",
  );
}

async function checkAudioSave(): Promise<ReadinessCheck> {
  if (!isBrowser()) {
    return check("unknown", "audio_save", "Audio save verification", "Server context.");
  }

  const entries = getAllEntries();
  const withAudio = entries.filter((entry) => entry.audioId).length;
  const indexedIds = new Set(await listAudioEntryIds());

  if (withAudio === 0) {
    return check("warn", "audio_save", "Audio save verification", "No audio entries yet — record one to verify.");
  }

  const missing = entries.filter(
    (entry) => entry.audioId && !indexedIds.has(entry.audioId),
  ).length;

  if (missing > 0) {
    return check(
      "fail",
      "audio_save",
      "Audio save verification",
      `${missing} entry reference(s) missing IndexedDB blob.`,
    );
  }

  return check(
    "pass",
    "audio_save",
    "Audio save verification",
    `${withAudio} audio entries · blobs present.`,
  );
}

function checkOfflineBehavior(): ReadinessCheck {
  if (!isBrowser()) {
    return check("unknown", "offline_mode", "Offline mode behavior", "Server context.");
  }

  const online = navigator.onLine;
  return check(
    online ? "pass" : "warn",
    "offline_mode",
    "Offline mode behavior",
    online
      ? "Online — local archive works offline; sync resumes when connected."
      : "Offline now — local reads/writes should still work.",
  );
}

async function checkLowStorageRisk(): Promise<ReadinessCheck> {
  if (!isBrowser()) {
    return check("unknown", "low_storage", "Low-storage risk", "Server context.");
  }

  let used = 0;
  for (let i = 0; i < localStorage.length; i += 1) {
    const key = localStorage.key(i);
    if (!key) continue;
    used += (localStorage.getItem(key)?.length ?? 0) * 2;
  }

  const storageReport = await buildStorageHealthReport();
  const issues = storageReport.issues.length;

  if (used > 4_000_000 || issues > 0) {
    return check(
      "warn",
      "low_storage",
      "Low-storage risk",
      `~${Math.round(used / 1024)}KB localStorage · ${issues} integrity issue(s).`,
    );
  }

  return check(
    "pass",
    "low_storage",
    "Low-storage risk",
    `~${Math.round(used / 1024)}KB localStorage · no integrity flags.`,
  );
}

function checkEncryptedSync(): ReadinessCheck {
  const lastBackup = readLastBackupAt();
  const lastSync = readLastSyncedAt();
  const syncError = readLastSyncError();

  if (syncError) {
    return check(
      "warn",
      "encrypted_sync",
      "Encrypted sync status",
      `Last error: ${syncError.slice(0, 120)}`,
    );
  }

  if (lastBackup || lastSync) {
    return check(
      "pass",
      "encrypted_sync",
      "Encrypted sync status",
      `Backup ${lastBackup ? "recorded" : "none"} · last sync ${lastSync ?? "never"}.`,
    );
  }

  return check(
    "warn",
    "encrypted_sync",
    "Encrypted sync status",
    "No backup or sync timestamp — expected if not signed in.",
  );
}

function checkLastBackup(): ReadinessCheck {
  const lastBackup = readLastBackupAt();
  if (!lastBackup) {
    return check("warn", "last_backup", "Last successful backup", "No backup timestamp recorded.");
  }
  return check("pass", "last_backup", "Last successful backup", lastBackup);
}

function checkRestorePreview(): ReadinessCheck {
  const hasSnapshot = hasPreRestoreBackup();
  const lastRestore = readLastRestoreAt();
  if (hasSnapshot) {
    return check(
      "pass",
      "restore_preview",
      "Restore preview availability",
      "Pre-restore snapshot available for rollback.",
    );
  }
  return check(
    lastRestore ? "pass" : "warn",
    "restore_preview",
    "Restore preview availability",
    lastRestore
      ? `Last restore ${lastRestore} — no pre-restore snapshot on disk.`
      : "No restore run yet — preview available after sign-in sync.",
  );
}

function checkStressTests(): ReadinessCheck {
  const report = readLastStressTestReport();
  if (!report) {
    return check("warn", "stress_tests", "Stress-test status", "No stress test run on this device.");
  }
  if (report.allPassed) {
    return check(
      "pass",
      "stress_tests",
      "Stress-test status",
      `All ${report.results.length} passed · ${report.runAt.slice(0, 10)}.`,
    );
  }
  return check(
    "fail",
    "stress_tests",
    "Stress-test status",
    `${report.failed} failed · ${report.runAt.slice(0, 10)}.`,
  );
}

function checkEnvironment(): ReadinessCheck {
  const nodeEnv = process.env.NODE_ENV ?? "unknown";
  const hasPublicUrl = Boolean(process.env.NEXT_PUBLIC_APP_URL);
  return check(
    nodeEnv === "production" || nodeEnv === "development" ? "pass" : "warn",
    "environment",
    "Build / environment config",
    `NODE_ENV=${nodeEnv}${hasPublicUrl ? " · app URL set" : ""}.`,
  );
}

/** Device and archive checks for production observation — debug only. */
export async function buildProductionReadinessReport(): Promise<ProductionReadinessReport> {
  const checks = await Promise.all([
    probeIndexedDb(),
    Promise.resolve(checkMicrophonePermission()),
    checkAudioSave(),
    Promise.resolve(checkOfflineBehavior()),
    checkLowStorageRisk(),
    Promise.resolve(checkEncryptedSync()),
    Promise.resolve(checkLastBackup()),
    Promise.resolve(checkRestorePreview()),
    Promise.resolve(checkStressTests()),
    Promise.resolve(checkEnvironment()),
  ]);

  const passed = checks.filter((row) => row.status === "pass").length;
  const failed = checks.filter((row) => row.status === "fail").length;
  const warnings = checks.filter((row) => row.status === "warn").length;
  const blocking = checks.filter((row) => row.status === "fail");

  return {
    generatedAt: new Date().toISOString(),
    checks,
    passed,
    failed,
    warnings,
    ready: blocking.length === 0 && failed === 0,
  };
}
