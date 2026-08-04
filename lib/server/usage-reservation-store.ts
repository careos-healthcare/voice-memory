import { createHash, randomUUID } from "node:crypto";

import {
  ensureDatabaseSchema,
  getDatabasePool,
  shouldUsePostgresStorage,
} from "@/lib/server/db";
import type {
  MonetizationCapabilityId,
  MonetizationPlanId,
  UsageMeterId,
} from "@/lib/server/monetization-policy";
import { MONETIZATION_POLICY_VERSION } from "@/lib/server/monetization-policy";

export type UsageReservationStatus = "reserved" | "committed" | "released";

export interface UsageReservation {
  reservationId: string;
  userId: string;
  planId: MonetizationPlanId;
  capabilityId: MonetizationCapabilityId;
  meterId: UsageMeterId;
  periodStart: string;
  periodEnd: string;
  unitsReserved: number;
  unitsCommitted: number;
  unitsReleased: number;
  providerInputUnits: number;
  providerOutputUnits: number;
  audioSeconds: number;
  policyVersion: string;
  safeResultCode: string | null;
  status: UsageReservationStatus;
  expiresAt: string;
  committedAt: string | null;
}

export type ReserveUsageResult =
  | { allowed: true; reservation: UsageReservation; duplicate: boolean }
  | { allowed: false; used: number; requested: number; allowance: number };

const memory = globalThis as typeof globalThis & {
  __vmUsageReservations?: Map<string, UsageReservation & { idempotencyHash: string }>;
};

function memoryRows() {
  if (!memory.__vmUsageReservations) memory.__vmUsageReservations = new Map();
  return memory.__vmUsageReservations;
}

function idempotencyHash(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

function memoryUniqueKey(input: {
  userId: string;
  meterId: UsageMeterId;
  periodStart: string;
  idempotencyKey: string;
}) {
  return `${input.userId}\0${input.meterId}\0${input.periodStart}\0${idempotencyHash(input.idempotencyKey)}`;
}

function publicRow(
  row: UsageReservation & { idempotencyHash?: string },
): UsageReservation {
  return {
    reservationId: row.reservationId,
    userId: row.userId,
    planId: row.planId,
    capabilityId: row.capabilityId,
    meterId: row.meterId,
    periodStart: row.periodStart,
    periodEnd: row.periodEnd,
    unitsReserved: row.unitsReserved,
    unitsCommitted: row.unitsCommitted,
    unitsReleased: row.unitsReleased,
    providerInputUnits: row.providerInputUnits,
    providerOutputUnits: row.providerOutputUnits,
    audioSeconds: row.audioSeconds,
    policyVersion: row.policyVersion,
    safeResultCode: row.safeResultCode,
    status: row.status,
    expiresAt: row.expiresAt,
    committedAt: row.committedAt,
  };
}

export async function reserveUsage(input: {
  userId: string;
  planId: MonetizationPlanId;
  capabilityId: MonetizationCapabilityId;
  meterId: UsageMeterId;
  periodStart: Date;
  periodEnd: Date;
  units: number;
  allowance: number;
  idempotencyKey: string;
}): Promise<ReserveUsageResult> {
  if (!Number.isSafeInteger(input.units) || input.units <= 0 ||
      !Number.isSafeInteger(input.allowance) || input.allowance < 0 ||
      !input.idempotencyKey.trim() || input.periodEnd <= input.periodStart) {
    throw new Error("USAGE_RESERVATION_INVALID");
  }
  const periodStart = input.periodStart.toISOString();
  const periodEnd = input.periodEnd.toISOString();
  const hash = idempotencyHash(input.idempotencyKey);

  if (!shouldUsePostgresStorage()) {
    const rows = memoryRows();
    const uniqueKey = memoryUniqueKey({ ...input, periodStart });
    const existing = rows.get(uniqueKey);
    if (existing && existing.status !== "released") {
      return { allowed: true, reservation: publicRow(existing), duplicate: true };
    }
    const now = Date.now();
    const used = [...rows.values()]
      .filter((row) =>
        row.userId === input.userId &&
        row.meterId === input.meterId &&
        row.periodStart === periodStart &&
        (row.status === "committed" ||
          (row.status === "reserved" && Date.parse(row.expiresAt) > now)))
      .reduce((sum, row) =>
        sum + (row.status === "committed" ? row.unitsCommitted : row.unitsReserved), 0);
    if (used + input.units > input.allowance) {
      return { allowed: false, used, requested: input.units, allowance: input.allowance };
    }
    const row = {
      reservationId: randomUUID(),
      userId: input.userId,
      planId: input.planId,
      capabilityId: input.capabilityId,
      meterId: input.meterId,
      periodStart,
      periodEnd,
      unitsReserved: input.units,
      unitsCommitted: 0,
      unitsReleased: 0,
      providerInputUnits: 0,
      providerOutputUnits: 0,
      audioSeconds: 0,
      policyVersion: MONETIZATION_POLICY_VERSION,
      safeResultCode: null,
      status: "reserved" as const,
      expiresAt: new Date(now + 15 * 60_000).toISOString(),
      committedAt: null,
      idempotencyHash: hash,
    };
    rows.set(uniqueKey, row);
    return { allowed: true, reservation: publicRow(row), duplicate: false };
  }

  await ensureDatabaseSchema();
  const client = await getDatabasePool().connect();
  try {
    await client.query("BEGIN");
    await client.query(
      "SELECT pg_advisory_xact_lock(hashtext($1), hashtext($2))",
      [input.userId, `${input.meterId}:${periodStart}`],
    );
    const existing = await client.query<DatabaseReservationRow>(
      `SELECT * FROM usage_reservations
       WHERE user_id = $1 AND meter_id = $2 AND period_start = $3
         AND idempotency_key_hash = $4`,
      [input.userId, input.meterId, input.periodStart, hash],
    );
    if (existing.rows[0] && existing.rows[0].status !== "released") {
      await client.query("COMMIT");
      return {
        allowed: true,
        reservation: fromDatabase(existing.rows[0]),
        duplicate: true,
      };
    }
    const total = await client.query<{ used: string }>(
      `SELECT COALESCE(sum(
         CASE WHEN status = 'committed' THEN units_committed ELSE units_reserved END
       ), 0)::text AS used
       FROM usage_reservations
       WHERE user_id = $1 AND meter_id = $2 AND period_start = $3
         AND (status = 'committed' OR (status = 'reserved' AND expires_at > now()))`,
      [input.userId, input.meterId, input.periodStart],
    );
    const used = Number(total.rows[0]?.used ?? 0);
    if (used + input.units > input.allowance) {
      await client.query("COMMIT");
      return { allowed: false, used, requested: input.units, allowance: input.allowance };
    }
    if (existing.rows[0]?.status === "released") {
      const retried = await client.query<DatabaseReservationRow>(
        `UPDATE usage_reservations
         SET plan_id = $2, capability_id = $3, period_end = $4,
             units_reserved = $5, units_committed = 0, status = 'reserved',
             units_released = 0, provider_input_units = 0,
             provider_output_units = 0, audio_seconds = 0,
             policy_version = $6, safe_result_code = NULL,
             expires_at = now() + interval '15 minutes',
             committed_at = NULL, released_at = NULL
         WHERE reservation_id = $1
         RETURNING *`,
        [
          existing.rows[0].reservation_id,
          input.planId,
          input.capabilityId,
          input.periodEnd,
          input.units,
          MONETIZATION_POLICY_VERSION,
        ],
      );
      await client.query("COMMIT");
      return {
        allowed: true,
        reservation: fromDatabase(retried.rows[0]),
        duplicate: false,
      };
    }
    const inserted = await client.query<DatabaseReservationRow>(
      `INSERT INTO usage_reservations
       (reservation_id, user_id, plan_id, capability_id, meter_id, period_start,
        period_end, units_reserved, idempotency_key_hash, status, expires_at,
        policy_version)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'reserved',now() + interval '15 minutes',$10)
       RETURNING *`,
      [
        randomUUID(), input.userId, input.planId, input.capabilityId, input.meterId,
        input.periodStart, input.periodEnd, input.units, hash,
        MONETIZATION_POLICY_VERSION,
      ],
    );
    await client.query("COMMIT");
    return { allowed: true, reservation: fromDatabase(inserted.rows[0]), duplicate: false };
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

export async function commitUsageReservation(
  reservationId: string,
  actualUnits: number,
  details: {
    providerInputUnits?: number;
    providerOutputUnits?: number;
    audioSeconds?: number;
    safeResultCode?: string;
  } = {},
): Promise<void> {
  const providerInputUnits = details.providerInputUnits ?? 0;
  const providerOutputUnits = details.providerOutputUnits ?? 0;
  const audioSeconds = details.audioSeconds ?? 0;
  const safeResultCode = details.safeResultCode ?? "completed";
  if (
    ![actualUnits, providerInputUnits, providerOutputUnits, audioSeconds].every(
      (value) => Number.isSafeInteger(value) && value >= 0,
    ) ||
    !/^[a-z][a-z0-9_]{0,63}$/.test(safeResultCode)
  ) {
    throw new Error("USAGE_COMMIT_INVALID");
  }
  if (!shouldUsePostgresStorage()) {
    for (const [key, row] of memoryRows()) {
      if (row.reservationId !== reservationId || row.status !== "reserved") continue;
      memoryRows().set(key, {
        ...row,
        status: "committed",
        unitsCommitted: actualUnits,
        providerInputUnits,
        providerOutputUnits,
        audioSeconds,
        safeResultCode,
        committedAt: new Date().toISOString(),
      });
      return;
    }
    return;
  }
  const result = await getDatabasePool().query(
    `UPDATE usage_reservations SET status = 'committed', units_committed = $2,
       provider_input_units = $3, provider_output_units = $4,
       audio_seconds = $5, safe_result_code = $6, committed_at = now()
     WHERE reservation_id = $1 AND status = 'reserved'`,
    [
      reservationId,
      actualUnits,
      providerInputUnits,
      providerOutputUnits,
      audioSeconds,
      safeResultCode,
    ],
  );
  if ((result.rowCount ?? 0) === 0) {
    const existing = await getDatabasePool().query<{ status: string }>(
      "SELECT status FROM usage_reservations WHERE reservation_id = $1",
      [reservationId],
    );
    if (existing.rows[0]?.status !== "committed") throw new Error("USAGE_COMMIT_CONFLICT");
  }
}

export async function releaseUsageReservation(reservationId: string): Promise<void> {
  if (!shouldUsePostgresStorage()) {
    for (const [key, row] of memoryRows()) {
      if (row.reservationId === reservationId && row.status === "reserved") {
        memoryRows().set(key, {
          ...row,
          status: "released",
          unitsReleased: row.unitsReserved,
          safeResultCode: "released",
        });
      }
    }
    return;
  }
  await getDatabasePool().query(
    `UPDATE usage_reservations SET status = 'released',
       units_released = units_reserved, safe_result_code = 'released',
       released_at = now()
     WHERE reservation_id = $1 AND status = 'reserved'`,
    [reservationId],
  );
}

export function resetUsageReservationsForTests(): void {
  memoryRows().clear();
}

export async function summarizeCommittedUsageByPlan(
  from: Date,
  to: Date,
): Promise<Array<{
  planId: MonetizationPlanId;
  meterId: UsageMeterId;
  committedUnits: number;
  operationCount: number;
}>> {
  if (to <= from) throw new Error("USAGE_REPORT_RANGE_INVALID");
  if (!shouldUsePostgresStorage()) {
    const grouped = new Map<string, {
      planId: MonetizationPlanId;
      meterId: UsageMeterId;
      committedUnits: number;
      operationCount: number;
    }>();
    for (const row of memoryRows().values()) {
      if (
        row.status !== "committed" ||
        !row.committedAt ||
        row.committedAt < from.toISOString() ||
        row.committedAt >= to.toISOString()
      ) continue;
      const key = `${row.planId}\0${row.meterId}`;
      const aggregate = grouped.get(key) ?? {
        planId: row.planId,
        meterId: row.meterId,
        committedUnits: 0,
        operationCount: 0,
      };
      aggregate.committedUnits += row.unitsCommitted;
      aggregate.operationCount += 1;
      grouped.set(key, aggregate);
    }
    return [...grouped.values()];
  }
  const result = await getDatabasePool().query<{
    plan_id: MonetizationPlanId;
    meter_id: UsageMeterId;
    committed_units: string;
    operation_count: string;
  }>(
    `SELECT plan_id, meter_id, sum(units_committed)::text AS committed_units,
            count(*)::text AS operation_count
     FROM usage_reservations
     WHERE status = 'committed' AND committed_at >= $1 AND committed_at < $2
     GROUP BY plan_id, meter_id ORDER BY plan_id, meter_id`,
    [from, to],
  );
  return result.rows.map((row) => ({
    planId: row.plan_id,
    meterId: row.meter_id,
    committedUnits: Number(row.committed_units),
    operationCount: Number(row.operation_count),
  }));
}

type DatabaseReservationRow = {
  reservation_id: string;
  user_id: string;
  plan_id: MonetizationPlanId;
  capability_id: MonetizationCapabilityId;
  meter_id: UsageMeterId;
  period_start: Date;
  period_end: Date;
  units_reserved: number;
  units_committed: number;
  units_released: number;
  provider_input_units: number;
  provider_output_units: number;
  audio_seconds: number;
  policy_version: string;
  safe_result_code: string | null;
  status: UsageReservationStatus;
  expires_at: Date;
  committed_at: Date | null;
};

function fromDatabase(row: DatabaseReservationRow): UsageReservation {
  return {
    reservationId: row.reservation_id,
    userId: row.user_id,
    planId: row.plan_id,
    capabilityId: row.capability_id,
    meterId: row.meter_id,
    periodStart: row.period_start.toISOString(),
    periodEnd: row.period_end.toISOString(),
    unitsReserved: Number(row.units_reserved),
    unitsCommitted: Number(row.units_committed),
    unitsReleased: Number(row.units_released),
    providerInputUnits: Number(row.provider_input_units),
    providerOutputUnits: Number(row.provider_output_units),
    audioSeconds: Number(row.audio_seconds),
    policyVersion: row.policy_version,
    safeResultCode: row.safe_result_code,
    status: row.status,
    expiresAt: row.expires_at.toISOString(),
    committedAt: row.committed_at?.toISOString() ?? null,
  };
}
