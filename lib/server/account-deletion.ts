import "server-only";

import { randomUUID } from "node:crypto";
import path from "node:path";

import { getServerBillingRecord } from "@/lib/server/billing-entitlements";
import { deleteServerBilling } from "@/lib/server/billing-entitlements";
import { deleteLocalAuthUser, localAuthUserExists } from "@/lib/server/auth-store";
import { deleteAllServerJournalEntries, listServerJournalEntries } from "@/lib/server/journal-store";
import {
  deleteAiAccuracyFeedbackForUser,
  localAiAccuracyFeedbackExists,
} from "@/lib/server/ai-feedback-store";
import {
  deleteApiUsageForSubject,
  localApiUsageExists,
} from "@/lib/server/api-usage-store";
import {
  deleteOpenAiSpendForSubject,
  localOpenAiSpendExists,
} from "@/lib/server/openai-spend-store";
import {
  deleteResurfacingFeedbackForUser,
  localResurfacingFeedbackExists,
} from "@/lib/server/resurfacing-feedback-store";
import {
  deleteLocalResurfacingEvents,
  localResurfacingEventsExist,
} from "@/lib/server/resurfacing-metrics-store";
import { deleteLocalSyncStore, localSyncStoreExists } from "@/lib/server/sync-store";
import {
  deleteMobilePushDevicesForUser,
  localMobilePushDevicesExist,
} from "@/lib/push/mobile-push-devices";
import { dbQuery, shouldUseFilesystemStorage, shouldUsePostgresStorage } from "@/lib/server/db";
import {
  EXTERNAL_DELETION_PROCESSORS,
  USER_DATA_DELETION_REGISTRY,
  USER_DATA_DELETION_REGISTRY_VERSION,
  type DeletionQuery,
  type UserDeletionContext,
} from "@/lib/server/privacy/user-data-deletion-registry";
import {
  deleteRevenueCatUserMapping,
  getRevenueCatUserMapping,
} from "@/lib/server/revenuecat-mapping";
import { getStripeClient } from "@/lib/server/stripe-client";
import { createEconomicsSubjectKeysForRotation } from "@/lib/server/unit-economics-subject-key";
export {
  assertAccountDeletionNotPending,
  isAccountDeletionPending,
} from "@/lib/server/privacy/account-deletion-state";

export type ExternalProcessor = "stripe-customer" | "revenuecat-subscriber";

export interface AccountDeletionResult {
  ok: boolean;
  pending: boolean;
  receiptId?: string;
  blockers: ExternalProcessor[];
}

export interface AccountDeletionExternalAdapters {
  deleteStripeCustomer(customerId: string): Promise<"complete" | "blocked" | "retry">;
  deleteRevenueCatSubscriber(appUserId: string): Promise<"complete" | "blocked" | "retry">;
}

const defaultExternalAdapters: AccountDeletionExternalAdapters = {
  async deleteStripeCustomer(customerId) {
    const stripe = getStripeClient();
    if (!stripe) return "blocked";
    try {
      await stripe.customers.del(customerId);
      return "complete";
    } catch (error) {
      const status = (error as { statusCode?: number }).statusCode;
      return status === 404 ? "complete" : "retry";
    }
  },
  async deleteRevenueCatSubscriber(appUserId) {
    const secret = process.env.REVENUECAT_SECRET_API_KEY?.trim();
    if (!secret) return "blocked";
    try {
      const response = await fetch(
        `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}`,
        {
          method: "DELETE",
          headers: { Authorization: `Bearer ${secret}`, Accept: "application/json" },
          cache: "no-store",
          signal: AbortSignal.timeout(10_000),
        },
      );
      if (response.ok || response.status === 404) return "complete";
      return response.status === 401 || response.status === 403 ? "blocked" : "retry";
    } catch {
      return "retry";
    }
  },
};

export async function runAccountDeletionExternalAdapter(
  processor: ExternalProcessor,
  externalId: string,
  adapters: AccountDeletionExternalAdapters,
): Promise<"complete" | "blocked" | "retry"> {
  return processor === "stripe-customer"
    ? adapters.deleteStripeCustomer(externalId)
    : adapters.deleteRevenueCatSubscriber(externalId);
}

function deletionContext(userId: string, email: string): UserDeletionContext {
  const normalizedEmail = email.trim().toLowerCase();
  const subjectKey = `user:${userId}`;
  const deleteLocal = async (resourceId: string): Promise<number> => {
    switch (resourceId) {
      case "sessions": return 0;
      case "auth-codes":
      case "profiles": return deleteLocalAuthUser(userId, normalizedEmail);
      case "sync-blobs": return deleteLocalSyncStore(userId);
      case "api-usage": return deleteApiUsageForSubject(subjectKey);
      case "api-minute-usage": return deleteApiUsageForSubject(subjectKey);
      case "openai-daily-spend": return deleteOpenAiSpendForSubject(subjectKey);
      case "journal-entries": return deleteAllServerJournalEntries(userId);
      case "resurfacing-events": return deleteLocalResurfacingEvents(userId, subjectKey);
      case "resurfacing-feedback":
        await deleteResurfacingFeedbackForUser(userId); return 0;
      case "ai-accuracy-feedback-and-corrections":
        return deleteAiAccuracyFeedbackForUser(userId);
      case "mobile-push-devices-and-fcm-tokens":
        return deleteMobilePushDevicesForUser(userId);
      case "billing-entitlements": await deleteServerBilling(userId); return 0;
      case "revenuecat-user-mappings": await deleteRevenueCatUserMapping(userId); return 0;
      case "unit-economics-rotated-hmac-subjects": return 0;
      default: throw new Error(`UNKNOWN_LOCAL_DELETION_RESOURCE:${resourceId}`);
    }
  };
  const verifyLocal = async (resourceId: string): Promise<boolean> => {
    switch (resourceId) {
      case "sessions":
      case "unit-economics-rotated-hmac-subjects": return true;
      case "auth-codes":
      case "profiles": return !localAuthUserExists(userId, normalizedEmail);
      case "sync-blobs": return !localSyncStoreExists(userId);
      case "api-usage":
      case "api-minute-usage": return !localApiUsageExists(subjectKey);
      case "openai-daily-spend": return !localOpenAiSpendExists(subjectKey);
      case "journal-entries": return (await listServerJournalEntries(userId)).length === 0;
      case "resurfacing-events": return !localResurfacingEventsExist(userId, subjectKey);
      case "resurfacing-feedback": return !localResurfacingFeedbackExists(userId);
      case "ai-accuracy-feedback-and-corrections":
        return !localAiAccuracyFeedbackExists(userId);
      case "mobile-push-devices-and-fcm-tokens":
        return !localMobilePushDevicesExist(userId);
      case "billing-entitlements": return (await getServerBillingRecord(userId)) === null;
      case "revenuecat-user-mappings": return (await getRevenueCatUserMapping(userId)) === null;
      default: return false;
    }
  };
  return {
    userId,
    normalizedEmail,
    subjectKey,
    economicsSubjectKeys: createEconomicsSubjectKeysForRotation("user", userId),
    syncDirectory: shouldUseFilesystemStorage()
      ? path.join(process.cwd(), ".data", "sync", userId)
      : null,
    storageMode: shouldUsePostgresStorage() ? "postgres" : "local",
    query: dbQuery as DeletionQuery,
    deleteLocal,
    verifyLocal,
  };
}

async function createOrResumeRequest(context: UserDeletionContext): Promise<string> {
  const requestId = randomUUID();
  const result = await dbQuery<{ request_id: string }>(
    `INSERT INTO account_deletion_requests
       (request_id, user_id, normalized_email, economics_subject_keys,
        status, registry_version, updated_at)
     VALUES ($1, $2, $3, $4::text[], 'processing', $5, now())
     ON CONFLICT (user_id) DO UPDATE SET
       normalized_email = EXCLUDED.normalized_email,
       economics_subject_keys = EXCLUDED.economics_subject_keys,
       status = 'processing',
       registry_version = EXCLUDED.registry_version,
       updated_at = now()
     RETURNING request_id`,
    [
      requestId,
      context.userId,
      context.normalizedEmail,
      context.economicsSubjectKeys,
      USER_DATA_DELETION_REGISTRY_VERSION,
    ],
  );
  return result.rows[0]?.request_id ?? requestId;
}

async function enqueueExternalMappings(
  requestId: string,
  userId: string,
): Promise<void> {
  const [billing, revenueCat] = await Promise.all([
    getServerBillingRecord(userId),
    getRevenueCatUserMapping(userId),
  ]);
  const jobs: Array<{ processor: ExternalProcessor; value: string }> = [];
  if (billing?.stripeCustomerId) {
    jobs.push({ processor: "stripe-customer", value: billing.stripeCustomerId });
  }
  if (revenueCat?.appUserId) {
    jobs.push({ processor: "revenuecat-subscriber", value: revenueCat.appUserId });
  }
  for (const job of jobs) {
    await dbQuery(
      `INSERT INTO account_deletion_outbox
         (job_id, request_id, processor, payload, status, next_attempt_at)
       VALUES ($1, $2, $3, jsonb_build_object('externalId', $4::text), 'pending', now())
       ON CONFLICT (request_id, processor) DO NOTHING`,
      [randomUUID(), requestId, job.processor, job.value],
    );
  }
}

async function processExternalJobs(
  requestId: string,
  adapters: AccountDeletionExternalAdapters,
): Promise<ExternalProcessor[]> {
  const jobs = await dbQuery<{
    job_id: string;
    processor: ExternalProcessor;
    payload: { externalId?: string };
    attempts: number;
  }>(
    `SELECT job_id, processor, payload, attempts
     FROM account_deletion_outbox
     WHERE request_id = $1 AND status IN ('pending', 'retry', 'blocked')
       AND (status = 'blocked' OR next_attempt_at <= now())
     ORDER BY created_at`,
    [requestId],
  );
  for (const job of jobs.rows) {
    const externalId = job.payload?.externalId;
    if (!externalId) {
      await dbQuery(
        `UPDATE account_deletion_outbox
         SET status = 'blocked', last_error_code = 'INVALID_MAPPING', updated_at = now()
         WHERE job_id = $1`,
        [job.job_id],
      );
      continue;
    }
    const registryEntry = EXTERNAL_DELETION_PROCESSORS.find(
      (entry) => entry.id === job.processor,
    );
    if (!registryEntry) throw new Error("UNKNOWN_EXTERNAL_DELETION_PROCESSOR");
    const outcome = await registryEntry.handler({
      externalId,
      run: (processor, value) =>
        runAccountDeletionExternalAdapter(processor as ExternalProcessor, value, adapters),
      status: async () => "pending",
    });
    const attempts = job.attempts + 1;
    const status = outcome === "complete" ? "complete" : outcome;
    await dbQuery(
      `UPDATE account_deletion_outbox
       SET status = $2, attempts = $3,
           next_attempt_at = CASE WHEN $2 = 'retry'
             THEN now() + make_interval(secs => LEAST(86400, power(2, LEAST($3, 16))::integer))
             ELSE next_attempt_at END,
           last_error_code = CASE
             WHEN $2 = 'blocked' THEN 'PROVIDER_NOT_CONFIGURED'
             WHEN $2 = 'retry' THEN 'PROVIDER_RETRY'
             ELSE NULL END,
           updated_at = now()
       WHERE job_id = $1`,
      [job.job_id, status, attempts],
    );
  }
  const remaining = await dbQuery<{ processor: ExternalProcessor }>(
    `SELECT processor FROM account_deletion_outbox
     WHERE request_id = $1 AND status <> 'complete'`,
    [requestId],
  );
  return remaining.rows.map((row) => row.processor);
}

async function deleteAndVerifyRegisteredData(context: UserDeletionContext): Promise<void> {
  for (const resource of USER_DATA_DELETION_REGISTRY) {
    await resource.handler(context);
  }
  for (const resource of USER_DATA_DELETION_REGISTRY) {
    if (!(await resource.verifier(context))) {
      throw new Error(`ACCOUNT_DELETION_VERIFY_FAILED:${resource.id}`);
    }
  }
}

async function completeRequest(requestId: string): Promise<string> {
  const receiptId = randomUUID();
  await dbQuery(
    `INSERT INTO account_deletion_receipts
       (receipt_id, registry_version, outcome, completed_at)
     VALUES ($1, $2, 'complete', now())`,
    [receiptId, USER_DATA_DELETION_REGISTRY_VERSION],
  );
  // Cascades outbox payloads and erases user-linked request state.
  await dbQuery(`DELETE FROM account_deletion_requests WHERE request_id = $1`, [requestId]);
  return receiptId;
}

export async function deleteUserServerData(
  userId: string,
  email: string,
  adapters: AccountDeletionExternalAdapters = defaultExternalAdapters,
): Promise<AccountDeletionResult> {
  const context = deletionContext(userId, email);
  if (!shouldUsePostgresStorage()) {
    await deleteAndVerifyRegisteredData(context);
    return { ok: true, pending: false, blockers: [] };
  }

  const requestId = await createOrResumeRequest(context);
  await enqueueExternalMappings(requestId, userId);

  // Sessions are the first registered resource and are revoked before all other erasure.
  await USER_DATA_DELETION_REGISTRY[0].handler(context);
  await deleteAndVerifyRegisteredData(context);
  const blockers = await processExternalJobs(requestId, adapters);
  if (blockers.length > 0) {
    await dbQuery(
      `UPDATE account_deletion_requests
       SET status = 'blocked', updated_at = now() WHERE request_id = $1`,
      [requestId],
    );
    return { ok: true, pending: true, blockers };
  }

  const receiptId = await completeRequest(requestId);
  return { ok: true, pending: false, receiptId, blockers: [] };
}

export async function processPendingAccountDeletionOutbox(
  adapters: AccountDeletionExternalAdapters = defaultExternalAdapters,
): Promise<{ completed: number; pending: number }> {
  if (!shouldUsePostgresStorage()) return { completed: 0, pending: 0 };
  const requests = await dbQuery<{
    request_id: string;
    user_id: string;
    normalized_email: string;
  }>(
    `SELECT request_id, user_id, normalized_email
     FROM account_deletion_requests
     ORDER BY created_at
     LIMIT 100`,
  );
  let completed = 0;
  let pending = 0;
  for (const request of requests.rows) {
    const context = deletionContext(request.user_id, request.normalized_email);
    await deleteAndVerifyRegisteredData(context);
    const blockers = await processExternalJobs(request.request_id, adapters);
    if (blockers.length > 0) {
      pending += 1;
      continue;
    }
    await completeRequest(request.request_id);
    completed += 1;
  }
  return { completed, pending };
}

export async function revokeAllSessionsForUser(userId: string): Promise<void> {
  if (!shouldUsePostgresStorage()) return;
  await dbQuery(`DELETE FROM sessions WHERE user_id = $1`, [userId]);
}
