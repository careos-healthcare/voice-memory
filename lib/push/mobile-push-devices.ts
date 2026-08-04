import "server-only";

import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";
import { assertAccountDeletionNotPending } from "@/lib/server/privacy/account-deletion-state";
import type { MobilePushPlatform } from "@/types/mobile-push";

const STALE_DAYS = 90;

type DeviceRow = {
  userId: string;
  deviceId: string;
  platform: MobilePushPlatform;
  fcmToken: string;
  updatedAt: string;
};

const globalPush = globalThis as typeof globalThis & {
  __vmMobilePushDevices?: Map<string, DeviceRow>;
};

function memoryMap(): Map<string, DeviceRow> {
  if (!globalPush.__vmMobilePushDevices) {
    globalPush.__vmMobilePushDevices = new Map();
  }
  return globalPush.__vmMobilePushDevices;
}

export async function upsertMobilePushDevice(params: {
  userId: string;
  deviceId: string;
  platform: MobilePushPlatform;
  fcmToken: string;
}): Promise<void> {
  if (!params.userId.startsWith("guest:")) {
    await assertAccountDeletionNotPending(params.userId);
  }
  if (shouldUsePostgresStorage()) {
    await dbQuery(
      `INSERT INTO mobile_push_devices (user_id, device_id, platform, fcm_token, created_at, updated_at)
       VALUES ($1, $2, $3, $4, now(), now())
       ON CONFLICT (device_id) DO UPDATE SET
         user_id = EXCLUDED.user_id,
         platform = EXCLUDED.platform,
         fcm_token = EXCLUDED.fcm_token,
         updated_at = now()`,
      [params.userId, params.deviceId, params.platform, params.fcmToken],
    );
    return;
  }
  memoryMap().set(params.deviceId, {
    userId: params.userId,
    deviceId: params.deviceId,
    platform: params.platform,
    fcmToken: params.fcmToken,
    updatedAt: new Date().toISOString(),
  });
}

export async function deleteMobilePushDevicesForUser(userId: string): Promise<number> {
  if (shouldUsePostgresStorage()) {
    const result = await dbQuery(`DELETE FROM mobile_push_devices WHERE user_id = $1`, [userId]);
    return result.rowCount ?? 0;
  }
  let removed = 0;
  for (const [deviceId, row] of memoryMap()) {
    if (row.userId === userId) {
      memoryMap().delete(deviceId);
      removed += 1;
    }
  }
  return removed;
}

export function localMobilePushDevicesExist(userId: string): boolean {
  return [...memoryMap().values()].some((row) => row.userId === userId);
}

export async function getFcmTokenForDevice(deviceId: string): Promise<string | null> {
  if (shouldUsePostgresStorage()) {
    const row = await dbQuery<{ fcm_token: string }>(
      `SELECT fcm_token FROM mobile_push_devices WHERE device_id = $1 LIMIT 1`,
      [deviceId],
    );
    return row.rows[0]?.fcm_token ?? null;
  }
  return memoryMap().get(deviceId)?.fcmToken ?? null;
}

export async function removeMobilePushDevice(deviceId: string): Promise<void> {
  if (shouldUsePostgresStorage()) {
    await dbQuery(`DELETE FROM mobile_push_devices WHERE device_id = $1`, [deviceId]);
    return;
  }
  memoryMap().delete(deviceId);
}

/** Drop tokens not refreshed within STALE_DAYS. */
export async function pruneStaleMobilePushDevices(): Promise<number> {
  if (shouldUsePostgresStorage()) {
    const row = await dbQuery<{ count: string }>(
      `WITH deleted AS (
         DELETE FROM mobile_push_devices
         WHERE updated_at < now() - interval '${STALE_DAYS} days'
         RETURNING 1
       )
       SELECT count(*)::text AS count FROM deleted`,
    );
    return Number(row.rows[0]?.count ?? 0);
  }
  const cutoff = Date.now() - STALE_DAYS * 24 * 60 * 60 * 1000;
  let removed = 0;
  for (const [id, row] of memoryMap()) {
    if (new Date(row.updatedAt).getTime() < cutoff) {
      memoryMap().delete(id);
      removed += 1;
    }
  }
  return removed;
}

export function resolvePushUserId(sessionUserId: string | null, deviceId: string): string {
  if (sessionUserId) return sessionUserId;
  return `guest:${deviceId}`;
}
