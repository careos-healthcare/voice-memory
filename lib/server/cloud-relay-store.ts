import "server-only";

import path from "node:path";

import {
  dbQuery,
  shouldUseFilesystemStorage,
  shouldUsePostgresStorage,
} from "@/lib/server/db";
import {
  ensureDataDir,
  readJsonFile,
  writeJsonFile,
} from "@/lib/server/data-path";
import {
  CLOUD_RELAY_MAX_VAULT_BYTES,
  CLOUD_RELAY_RETENTION_MS,
} from "@/lib/sync/cloud-relay-contract";
import type { SyncBlobRecord } from "@/types/sync";

export interface CloudRelayDeviceRecord {
  id: string;
  lastActiveAt: string;
}

interface CloudRelayQueueItem {
  envelope: SyncBlobRecord;
  sourceDeviceId: string;
  targetDeviceId: string;
  expiresAt: string;
}

interface CloudRelayVault {
  version: 1;
  devices: Record<string, CloudRelayDeviceRecord>;
  queue: CloudRelayQueueItem[];
}

const globalRelay = globalThis as typeof globalThis & {
  __archiveMeCloudRelay?: Record<string, CloudRelayVault>;
  __archiveMeCloudRelayLocks?: Record<string, Promise<void>>;
};

function emptyVault(): CloudRelayVault {
  return { version: 1, devices: {}, queue: [] };
}

function memoryVault(vaultHash: string): CloudRelayVault {
  globalRelay.__archiveMeCloudRelay ??= {};
  globalRelay.__archiveMeCloudRelay[vaultHash] ??= emptyVault();
  return globalRelay.__archiveMeCloudRelay[vaultHash];
}

function vaultPath(vaultHash: string): string {
  return path.join(ensureDataDir("cloud-relay"), `${vaultHash}.json`);
}

function readVault(vaultHash: string): CloudRelayVault {
  if (shouldUseFilesystemStorage()) {
    return readJsonFile<CloudRelayVault>(vaultPath(vaultHash), emptyVault());
  }
  return memoryVault(vaultHash);
}

function writeVault(vaultHash: string, vault: CloudRelayVault): void {
  if (shouldUseFilesystemStorage()) {
    writeJsonFile(vaultPath(vaultHash), vault);
  }
}

async function serialized<T>(
  vaultHash: string,
  operation: () => Promise<T> | T,
): Promise<T> {
  globalRelay.__archiveMeCloudRelayLocks ??= {};
  const previous =
    globalRelay.__archiveMeCloudRelayLocks[vaultHash] ?? Promise.resolve();
  let release!: () => void;
  const current = new Promise<void>((resolve) => {
    release = resolve;
  });
  globalRelay.__archiveMeCloudRelayLocks[vaultHash] = previous.then(
    () => current,
    () => current,
  );
  await previous.catch(() => undefined);
  try {
    return await operation();
  } finally {
    release();
  }
}

function prune(vault: CloudRelayVault, now: Date): void {
  vault.queue = vault.queue.filter(
    (item) => Date.parse(item.expiresAt) > now.getTime(),
  );
}

function vaultBytes(vault: CloudRelayVault): number {
  return vault.queue.reduce(
    (total, item) => total + item.envelope.byteLength,
    0,
  );
}

export async function registerCloudRelayDevice(
  vaultHash: string,
  deviceId: string,
  now = new Date(),
): Promise<void> {
  if (shouldUsePostgresStorage()) {
    await dbQuery(
      `INSERT INTO cloud_relay_devices (vault_hash, device_id, last_active_at)
       VALUES ($1, $2, $3)
       ON CONFLICT (vault_hash, device_id) DO UPDATE
       SET last_active_at = EXCLUDED.last_active_at`,
      [vaultHash, deviceId, now.toISOString()],
    );
    await dbQuery(
      `UPDATE cloud_relay_envelopes
       SET target_device_id = $2
       WHERE vault_hash = $1
         AND target_device_id = '*'
         AND source_device_id <> $2`,
      [vaultHash, deviceId],
    );
    return;
  }
  await serialized(vaultHash, () => {
    const vault = readVault(vaultHash);
    prune(vault, now);
    vault.devices[deviceId] = {
      id: deviceId,
      lastActiveAt: now.toISOString(),
    };
    for (const item of vault.queue) {
      if (item.targetDeviceId === "*" && item.sourceDeviceId !== deviceId) {
        item.targetDeviceId = deviceId;
      }
    }
    writeVault(vaultHash, vault);
  });
}

export async function pushCloudRelayEnvelopes(
  vaultHash: string,
  sourceDeviceId: string,
  envelopes: SyncBlobRecord[],
  now = new Date(),
): Promise<void> {
  await registerCloudRelayDevice(vaultHash, sourceDeviceId, now);
  const expiresAt = new Date(now.getTime() + CLOUD_RELAY_RETENTION_MS);
  if (shouldUsePostgresStorage()) {
    await dbQuery(`DELETE FROM cloud_relay_envelopes WHERE expires_at <= $1`, [
      now.toISOString(),
    ]);
    const usage = await dbQuery<{ bytes: string }>(
      `SELECT COALESCE(SUM(byte_length), 0)::text AS bytes
       FROM cloud_relay_envelopes WHERE vault_hash = $1`,
      [vaultHash],
    );
    const incoming = envelopes.reduce(
      (total, envelope) => total + envelope.byteLength,
      0,
    );
    if (
      Number(usage.rows[0]?.bytes ?? 0) + incoming >
      CLOUD_RELAY_MAX_VAULT_BYTES
    ) {
      throw new Error("Relay vault capacity exceeded.");
    }
    const devices = await dbQuery<{ device_id: string }>(
      `SELECT device_id FROM cloud_relay_devices
       WHERE vault_hash = $1 AND device_id <> $2`,
      [vaultHash, sourceDeviceId],
    );
    const targets =
      devices.rows.length > 0
        ? devices.rows.map((row) => row.device_id)
        : ["*"];
    for (const envelope of envelopes) {
      for (const target of targets) {
        await dbQuery(
          `INSERT INTO cloud_relay_envelopes (
             vault_hash, envelope_id, source_device_id, target_device_id,
             envelope, byte_length, created_at, expires_at
           ) VALUES ($1, $2, $3, $4, $5::jsonb, $6, $7, $8)
           ON CONFLICT (vault_hash, envelope_id, target_device_id) DO UPDATE SET
             envelope = EXCLUDED.envelope,
             byte_length = EXCLUDED.byte_length,
             expires_at = EXCLUDED.expires_at`,
          [
            vaultHash,
            envelope.id,
            sourceDeviceId,
            target,
            JSON.stringify(envelope),
            envelope.byteLength,
            now.toISOString(),
            expiresAt.toISOString(),
          ],
        );
      }
    }
    return;
  }
  await serialized(vaultHash, () => {
    const vault = readVault(vaultHash);
    prune(vault, now);
    const incoming = envelopes.reduce(
      (total, envelope) => total + envelope.byteLength,
      0,
    );
    if (vaultBytes(vault) + incoming > CLOUD_RELAY_MAX_VAULT_BYTES) {
      throw new Error("Relay vault capacity exceeded.");
    }
    const targets = Object.keys(vault.devices).filter(
      (deviceId) => deviceId !== sourceDeviceId,
    );
    for (const envelope of envelopes) {
      for (const targetDeviceId of targets.length > 0 ? targets : ["*"]) {
        vault.queue = vault.queue.filter(
          (item) =>
            item.envelope.id !== envelope.id ||
            item.targetDeviceId !== targetDeviceId,
        );
        vault.queue.push({
          envelope,
          sourceDeviceId,
          targetDeviceId,
          expiresAt: expiresAt.toISOString(),
        });
      }
    }
    writeVault(vaultHash, vault);
  });
}

export async function takeCloudRelayEnvelopes(
  vaultHash: string,
  deviceId: string,
  now = new Date(),
): Promise<SyncBlobRecord[]> {
  await registerCloudRelayDevice(vaultHash, deviceId, now);
  if (shouldUsePostgresStorage()) {
    await dbQuery(`DELETE FROM cloud_relay_envelopes WHERE expires_at <= $1`, [
      now.toISOString(),
    ]);
    const result = await dbQuery<{ envelope: SyncBlobRecord }>(
      `DELETE FROM cloud_relay_envelopes
       WHERE vault_hash = $1 AND target_device_id = $2
       RETURNING envelope`,
      [vaultHash, deviceId],
    );
    return result.rows.map((row) => row.envelope);
  }
  return serialized(vaultHash, () => {
    const vault = readVault(vaultHash);
    prune(vault, now);
    const selected = vault.queue.filter(
      (item) => item.targetDeviceId === deviceId,
    );
    vault.queue = vault.queue.filter(
      (item) => item.targetDeviceId !== deviceId,
    );
    writeVault(vaultHash, vault);
    return selected.map((item) => item.envelope);
  });
}

export async function listCloudRelayDevices(
  vaultHash: string,
): Promise<CloudRelayDeviceRecord[]> {
  if (shouldUsePostgresStorage()) {
    const result = await dbQuery<{
      device_id: string;
      last_active_at: string;
    }>(
      `SELECT device_id, last_active_at FROM cloud_relay_devices
       WHERE vault_hash = $1 ORDER BY device_id`,
      [vaultHash],
    );
    return result.rows.map((row) => ({
      id: row.device_id,
      lastActiveAt: row.last_active_at,
    }));
  }
  return serialized(vaultHash, () =>
    Object.values(readVault(vaultHash).devices).sort((left, right) =>
      left.id.localeCompare(right.id),
    ),
  );
}

export async function revokeCloudRelayDevice(
  vaultHash: string,
  revokedDeviceId: string,
): Promise<void> {
  if (shouldUsePostgresStorage()) {
    await Promise.all([
      dbQuery(
        `DELETE FROM cloud_relay_devices
         WHERE vault_hash = $1 AND device_id = $2`,
        [vaultHash, revokedDeviceId],
      ),
      dbQuery(
        `DELETE FROM cloud_relay_envelopes
         WHERE vault_hash = $1
           AND (source_device_id = $2 OR target_device_id = $2)`,
        [vaultHash, revokedDeviceId],
      ),
    ]);
    return;
  }
  await serialized(vaultHash, () => {
    const vault = readVault(vaultHash);
    delete vault.devices[revokedDeviceId];
    vault.queue = vault.queue.filter(
      (item) =>
        item.sourceDeviceId !== revokedDeviceId &&
        item.targetDeviceId !== revokedDeviceId,
    );
    writeVault(vaultHash, vault);
  });
}

export function resetCloudRelayMemoryStoreForTests(): void {
  globalRelay.__archiveMeCloudRelay = {};
  globalRelay.__archiveMeCloudRelayLocks = {};
}
