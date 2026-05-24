import { buildStorageHealthReport } from "@/lib/reliability/integrity";
import { readLastStressTestReport } from "@/lib/reliability/stress-tests";
import { buildSyncHealthReport } from "@/lib/sync/sync-health";
import { readLastSyncError } from "@/lib/sync/status-storage";
import type { IncidentBundle, IncidentKind, IncidentRecord } from "@/types/validation-phase";

const INCIDENTS_KEY = "voicememory_incidents";
const MAX_INCIDENTS = 200;

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readStoredIncidents(): IncidentRecord[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(INCIDENTS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as IncidentRecord[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeStoredIncidents(incidents: IncidentRecord[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(INCIDENTS_KEY, JSON.stringify(incidents.slice(-MAX_INCIDENTS)));
}

function incidentFingerprint(kind: IncidentKind, detail: string): string {
  return `${kind}:${detail.slice(0, 120)}`;
}

export function recordIncident(input: {
  kind: IncidentKind;
  detail: string;
  meta?: Record<string, string>;
}): IncidentRecord | null {
  const detail = input.detail.trim();
  if (!detail) return null;

  const fingerprint = incidentFingerprint(input.kind, detail);
  const existing = readStoredIncidents();
  const duplicate = existing.find(
    (row) => !row.resolved && incidentFingerprint(row.kind, row.detail) === fingerprint,
  );
  if (duplicate) return duplicate;

  const record: IncidentRecord = {
    id: crypto.randomUUID(),
    kind: input.kind,
    detail: detail.slice(0, 500),
    detectedAt: new Date().toISOString(),
    meta: input.meta,
  };

  writeStoredIncidents([...existing, record]);
  return record;
}

export function resolveIncident(incidentId: string): void {
  const incidents = readStoredIncidents().map((row) =>
    row.id === incidentId ? { ...row, resolved: true } : row,
  );
  writeStoredIncidents(incidents);
}

export function clearResolvedIncidents(): number {
  const before = readStoredIncidents();
  const kept = before.filter((row) => !row.resolved);
  writeStoredIncidents(kept);
  return before.length - kept.length;
}

async function scanLiveIncidents(): Promise<IncidentRecord[]> {
  const live: IncidentRecord[] = [];
  const now = new Date().toISOString();

  const syncError = readLastSyncError();
  if (syncError) {
    live.push({
      id: "live-sync-error",
      kind: "failed_sync",
      detail: syncError.slice(0, 500),
      detectedAt: now,
    });
  }

  try {
    const syncHealth = await buildSyncHealthReport();
    if (syncHealth.lastRestoreAt && syncHealth.issues.some((row) => row.type === "sync_error")) {
      live.push({
        id: "live-restore-error",
        kind: "failed_restore",
        detail: syncHealth.issues.find((row) => row.type === "sync_error")?.detail ?? "Restore issue detected.",
        detectedAt: now,
      });
    }

    for (const issue of syncHealth.issues) {
      if (issue.type === "corrupted_remote_blob") {
        live.push({
          id: `live-corrupt-${issue.detail.slice(0, 20)}`,
          kind: "corrupted_export",
          detail: issue.detail,
          detectedAt: now,
        });
      }
      if (issue.type === "missing_audio_metadata") {
        live.push({
          id: `live-replay-${issue.entryId ?? "unknown"}`,
          kind: "replay_mismatch",
          detail: issue.detail,
          detectedAt: now,
          meta: issue.entryId ? { entryId: issue.entryId } : undefined,
        });
      }
    }
  } catch {
    live.push({
      id: "live-sync-scan-failed",
      kind: "failed_sync",
      detail: "Could not complete sync health scan.",
      detectedAt: now,
    });
  }

  try {
    const storage = await buildStorageHealthReport();
    for (const issue of storage.issues) {
      if (issue.type === "missing_audio_reference") {
        live.push({
          id: `live-audio-${issue.entryId ?? "unknown"}`,
          kind: "missing_audio",
          detail: issue.detail,
          detectedAt: now,
          meta: issue.entryId ? { entryId: issue.entryId } : undefined,
        });
      }
    }
  } catch {
    live.push({
      id: "live-storage-scan-failed",
      kind: "indexeddb_failure",
      detail: "Storage health scan failed — IndexedDB may be unavailable.",
      detectedAt: now,
    });
  }

  if (isBrowser() && typeof indexedDB === "undefined") {
    live.push({
      id: "live-indexeddb-missing",
      kind: "indexeddb_failure",
      detail: "indexedDB is not available in this browser context.",
      detectedAt: now,
    });
  }

  if (isBrowser()) {
    let used = 0;
    for (let i = 0; i < localStorage.length; i += 1) {
      const key = localStorage.key(i);
      if (!key) continue;
      used += (localStorage.getItem(key)?.length ?? 0) * 2;
    }
    if (used > 4_500_000) {
      live.push({
        id: "live-quota-risk",
        kind: "quota_issue",
        detail: `localStorage near capacity (~${Math.round(used / 1024)}KB used).`,
        detectedAt: now,
      });
    }
  }

  const stress = readLastStressTestReport();
  if (stress && !stress.allPassed) {
    live.push({
      id: "live-stress-failures",
      kind: "corrupted_export",
      detail: `${stress.failed} archive stress test(s) failed on ${stress.runAt.slice(0, 10)}.`,
      detectedAt: now,
    });
  }

  return live;
}

/** Scan current device state and persist any new incidents. */
export async function scanAndPersistIncidents(): Promise<IncidentRecord[]> {
  const live = await scanLiveIncidents();
  for (const row of live) {
    recordIncident({ kind: row.kind, detail: row.detail, meta: row.meta });
  }
  return live;
}

export async function buildIncidentBundle(): Promise<IncidentBundle> {
  const liveScan = await scanLiveIncidents();
  const incidents = readStoredIncidents().sort(
    (a, b) => new Date(b.detectedAt).getTime() - new Date(a.detectedAt).getTime(),
  );

  return {
    exportedAt: new Date().toISOString(),
    incidentCount: incidents.length,
    openCount: incidents.filter((row) => !row.resolved).length,
    incidents,
    liveScan,
  };
}

export function downloadIncidentBundle(bundle: IncidentBundle): void {
  if (!isBrowser()) return;

  const blob = new Blob([JSON.stringify(bundle, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = `incident-bundle-${bundle.exportedAt.slice(0, 10)}.json`;
  anchor.click();
  URL.revokeObjectURL(url);
}

export const INCIDENT_KIND_LABELS: Record<IncidentKind, string> = {
  failed_sync: "Failed sync",
  failed_restore: "Failed restore",
  missing_audio: "Missing audio",
  corrupted_export: "Corrupted export",
  quota_issue: "Quota issue",
  indexeddb_failure: "IndexedDB failure",
  replay_mismatch: "Replay mismatch",
};
