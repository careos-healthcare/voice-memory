import "server-only";

import {
  dbQuery,
  shouldUsePostgresStorage,
} from "@/lib/server/db";
import { assertAccountDeletionNotPending } from "@/lib/server/privacy/account-deletion-state";

export interface RevenueCatUserMapping {
  userId: string;
  appUserId: string;
  updatedAt: string;
}

const UUID_V4 =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const SERVER_USER_ID = /^[0-9a-f]{32}$/i;

const memoryMappings = globalThis as typeof globalThis & {
  __vmRevenueCatMappings?: Map<string, RevenueCatUserMapping>;
};

function memoryMap(): Map<string, RevenueCatUserMapping> {
  if (!memoryMappings.__vmRevenueCatMappings) {
    memoryMappings.__vmRevenueCatMappings = new Map();
  }
  return memoryMappings.__vmRevenueCatMappings;
}

export function normalizeRevenueCatAppUserId(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const normalized = value.trim().toLowerCase();
  if (!UUID_V4.test(normalized) && !SERVER_USER_ID.test(normalized)) return null;
  return normalized;
}

export async function getRevenueCatUserMapping(
  userId: string,
): Promise<RevenueCatUserMapping | null> {
  if (shouldUsePostgresStorage()) {
    const result = await dbQuery<{
      user_id: string;
      app_user_id: string;
      updated_at: Date;
    }>(
      `SELECT user_id, app_user_id, updated_at
       FROM revenuecat_user_mappings WHERE user_id = $1`,
      [userId],
    );
    const row = result.rows[0];
    return row
      ? {
          userId: row.user_id,
          appUserId: row.app_user_id,
          updatedAt: row.updated_at.toISOString(),
        }
      : null;
  }
  return memoryMap().get(userId) ?? null;
}

export async function getRevenueCatMappingByAppUserId(
  appUserId: string,
): Promise<RevenueCatUserMapping | null> {
  const normalized = normalizeRevenueCatAppUserId(appUserId);
  if (!normalized) return null;
  if (shouldUsePostgresStorage()) {
    const result = await dbQuery<{
      user_id: string;
      app_user_id: string;
      updated_at: Date;
    }>(
      `SELECT user_id, app_user_id, updated_at
       FROM revenuecat_user_mappings WHERE app_user_id = $1`,
      [normalized],
    );
    const row = result.rows[0];
    return row
      ? {
          userId: row.user_id,
          appUserId: row.app_user_id,
          updatedAt: row.updated_at.toISOString(),
        }
      : null;
  }
  return [...memoryMap().values()].find(
    (mapping) => mapping.appUserId === normalized,
  ) ?? null;
}

export async function upsertRevenueCatUserMapping(
  userId: string,
  appUserId: string,
): Promise<RevenueCatUserMapping> {
  await assertAccountDeletionNotPending(userId);
  const normalized = normalizeRevenueCatAppUserId(appUserId);
  if (!normalized) throw new Error("invalid_revenuecat_app_user_id");

  if (shouldUsePostgresStorage()) {
    await dbQuery(
      `INSERT INTO revenuecat_user_mappings (user_id, app_user_id, updated_at)
       VALUES ($1, $2, now())
       ON CONFLICT (user_id) DO UPDATE SET
         app_user_id = EXCLUDED.app_user_id,
         updated_at = now()`,
      [userId, normalized],
    );
    const mapping = await getRevenueCatUserMapping(userId);
    if (!mapping) throw new Error("revenuecat_mapping_upsert_failed");
    return mapping;
  }

  for (const mapping of memoryMap().values()) {
    if (mapping.appUserId === normalized && mapping.userId !== userId) {
      throw new Error("revenuecat_app_user_id_in_use");
    }
  }
  const mapping = {
    userId,
    appUserId: normalized,
    updatedAt: new Date().toISOString(),
  };
  memoryMap().set(userId, mapping);
  return mapping;
}

export async function deleteRevenueCatUserMapping(userId: string): Promise<void> {
  if (shouldUsePostgresStorage()) {
    await dbQuery(`DELETE FROM revenuecat_user_mappings WHERE user_id = $1`, [
      userId,
    ]);
    return;
  }
  memoryMap().delete(userId);
}

export function __resetRevenueCatMappingsForTests(): void {
  memoryMap().clear();
}
