import "server-only";

import { randomUUID } from "node:crypto";

import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";
import { isFcmConfigured, isStaleTokenError } from "@/lib/push/fcm-admin";
import { getFcmTokenForDevice, removeMobilePushDevice } from "@/lib/push/mobile-push-devices";

import { curiosityAdaptiveTimingEngine } from "./curiosity_adaptive_timing_engine";
import {
  evaluateCuriosityEvidenceGate,
  recordCuriositySurface,
} from "./curiosity_evidence_gate";
import { buildCuriosityNotificationMessage } from "./curiosity_notification_message_builder";
import { emitCuriosityLoopTelemetry } from "@/src/internal/loops/telemetry/curiosity_loop_telemetry";
import type {
  CuriosityHook,
  CuriosityHookEntryMetadata,
  CuriosityJournalEntryTiming,
  QueuedCuriosityNotification,
} from "./types";

function assertPostgresAvailable(): void {
  if (!shouldUsePostgresStorage()) {
    throw new Error("DATABASE_URL is required for curiosity notification scheduling.");
  }
}

async function insertQueuedNotification(input: {
  userId: string;
  deviceId: string;
  hookId: string;
  queryText: string;
  title: string;
  body: string;
  citedEntryIds: string[];
  fireAt: Date;
}): Promise<string> {
  assertPostgresAvailable();
  const id = randomUUID();
  await dbQuery(
    `INSERT INTO curiosity_notification_queue
       (id, user_id, device_id, hook_id, query_text, title, body, cited_entry_ids, fire_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::timestamptz)`,
    [
      id,
      input.userId,
      input.deviceId,
      input.hookId,
      input.queryText,
      input.title,
      input.body,
      input.citedEntryIds,
      input.fireAt.toISOString(),
    ],
  );
  return id;
}

async function listDueNotifications(now: Date): Promise<QueuedCuriosityNotification[]> {
  assertPostgresAvailable();
  const result = await dbQuery<{
    id: string;
    user_id: string;
    device_id: string;
    hook_id: string;
    query_text: string;
    title: string;
    body: string;
    cited_entry_ids: string[];
    fire_at: Date | string;
  }>(
    `SELECT id, user_id, device_id, hook_id, query_text, title, body, cited_entry_ids, fire_at
     FROM curiosity_notification_queue
     WHERE sent_at IS NULL
       AND cancelled_at IS NULL
       AND fire_at <= $1::timestamptz
     ORDER BY fire_at ASC
     LIMIT 50`,
    [now.toISOString()],
  );

  return result.rows.map((row) => ({
    id: String(row.id),
    userId: row.user_id,
    deviceId: row.device_id,
    hookId: row.hook_id,
    queryText: row.query_text,
    title: row.title,
    body: row.body,
    citedEntryIds: row.cited_entry_ids ?? [],
    fireAt:
      row.fire_at instanceof Date ? row.fire_at.toISOString() : String(row.fire_at),
  }));
}

async function markNotificationSent(id: string): Promise<void> {
  await dbQuery(
    `UPDATE curiosity_notification_queue SET sent_at = now() WHERE id = $1`,
    [id],
  );
}

async function cancelNotification(id: string): Promise<void> {
  await dbQuery(
    `UPDATE curiosity_notification_queue SET cancelled_at = now() WHERE id = $1`,
    [id],
  );
}

async function sendCuriosityPush(input: {
  token: string;
  title: string;
  body: string;
  hookId: string;
  citedEntryIds: string[];
}): Promise<{ messageId: string }> {
  if (!isFcmConfigured()) {
    throw new Error("FCM_NOT_CONFIGURED");
  }

  const admin = await import("firebase-admin");
  if (!admin.apps.length) {
    const json = process.env.FIREBASE_SERVICE_ACCOUNT_JSON?.trim();
    if (!json) throw new Error("FCM_NOT_CONFIGURED");
    const account = JSON.parse(json) as {
      project_id: string;
      client_email: string;
      private_key: string;
    };
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId: account.project_id,
        clientEmail: account.client_email,
        privateKey: account.private_key,
      }),
    });
  }

  const messageId = await admin.messaging().send({
    token: input.token,
    notification: {
      title: input.title,
      body: input.body,
    },
    data: {
      type: "curiosity_hook_v1",
      hookId: input.hookId,
      citedEntryIds: input.citedEntryIds.join(","),
      route: "/record",
    },
    android: { priority: "high" },
    apns: { payload: { aps: { sound: "default" } } },
  });

  return { messageId: String(messageId) };
}

export interface QueueCuriosityNotificationInput {
  userId: string;
  deviceId: string;
  hook: CuriosityHook;
  queryText: string;
  journalHistory?: readonly CuriosityJournalEntryTiming[];
  currentEntryTime?: Date;
}

export interface QueueCuriosityNotificationResult {
  queued: boolean;
  queueId?: string;
  fireAt?: string;
  reason?: string;
}

/**
 * Runs the evidence gate before enqueueing a background push notification.
 */
export async function queueCuriosityNotification(
  input: QueueCuriosityNotificationInput,
): Promise<QueueCuriosityNotificationResult> {
  const evidence = await evaluateCuriosityEvidenceGate(input.userId, input.queryText);
  if (!evidence.eligible) {
    return { queued: false, reason: evidence.reason };
  }

  const message = buildCuriosityNotificationMessage({
    hook: input.hook,
    evidence,
  });
  if (!message) {
    return { queued: false, reason: "generic_message_rejected" };
  }

  const delayMs = curiosityAdaptiveTimingEngine.calculateOptimalDelayMs({
    history: input.journalHistory ?? [{ createdAt: input.hook.createdAt }],
    currentEntryTime: input.currentEntryTime ?? new Date(input.hook.createdAt),
  });
  const fireAt = new Date(Date.now() + delayMs);

  const queueId = await insertQueuedNotification({
    userId: input.userId,
    deviceId: input.deviceId,
    hookId: message.hookId,
    queryText: input.queryText,
    title: message.title,
    body: message.body,
    citedEntryIds: message.citedEntryIds,
    fireAt,
  });

  emitCuriosityLoopTelemetry("hook_scheduled", {
    hookId: message.hookId,
    queueId,
    scheduleAfterMinutes: Math.round(delayMs / 60_000),
  });

  return { queued: true, queueId, fireAt: fireAt.toISOString() };
}

export interface DispatchDueCuriosityNotificationsResult {
  processed: number;
  sent: number;
  cancelled: number;
  failed: number;
}

/**
 * Background dispatcher — re-runs evidence checks immediately before send.
 */
export async function dispatchDueCuriosityNotifications(
  now = new Date(),
): Promise<DispatchDueCuriosityNotificationsResult> {
  const due = await listDueNotifications(now);
  let sent = 0;
  let cancelled = 0;
  let failed = 0;

  for (const row of due) {
    try {
      const evidence = await evaluateCuriosityEvidenceGate(row.userId, row.queryText);
      if (!evidence.eligible) {
        await cancelNotification(row.id);
        emitCuriosityLoopTelemetry("hook_dispatch_cancelled", {
          queueId: row.id,
          reason: evidence.reason,
        });
        cancelled += 1;
        continue;
      }

      const token = await getFcmTokenForDevice(row.deviceId);
      if (!token) {
        await cancelNotification(row.id);
        cancelled += 1;
        continue;
      }

      await sendCuriosityPush({
        token,
        title: row.title,
        body: row.body,
        hookId: row.hookId,
        citedEntryIds: row.citedEntryIds,
      });

      if (evidence.surfaceKey) {
        await recordCuriositySurface({
          userId: row.userId,
          surfaceKey: evidence.surfaceKey,
          kind: evidence.reason === "unsurfaced_contradiction" ? "contradiction" : "pattern",
          citedEntryIds: evidence.citedEntryIds,
        });
      }

      await markNotificationSent(row.id);
      sent += 1;
    } catch (error) {
      if (isStaleTokenError(error)) {
        await removeMobilePushDevice(row.deviceId);
        await cancelNotification(row.id);
        cancelled += 1;
        continue;
      }
      failed += 1;
    }
  }

  return {
    processed: due.length,
    sent,
    cancelled,
    failed,
  };
}

export type { CuriosityHookEntryMetadata };
