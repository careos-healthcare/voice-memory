import "server-only";

import { hashSessionToken, hashUserIdForAudit } from "@/lib/server/auth-crypto";
import {
  deleteAuthCodesForEmailPostgres,
  deleteSessionsForUserPostgres,
  revokeSessionPostgres,
} from "@/lib/server/auth-store-postgres";
import { deleteLocalAuthIdentity } from "@/lib/server/auth-storage";
import { deleteApiUsageForSubject } from "@/lib/server/api-usage-store";
import { currentBillingStorageMode, deleteServerBilling } from "@/lib/server/billing-entitlements";
import { shouldUsePostgresStorage } from "@/lib/server/db";
import { currentJournalStorageMode, deleteAllServerJournalEntries } from "@/lib/server/journal-store";
import { deleteLiveAudioSessionsForSubject } from "@/lib/live-audio/session-store";
import { deleteOpenAiSpendForSubject } from "@/lib/server/openai-spend-store";
import { deleteResurfacingEventsForUser } from "@/lib/server/resurfacing-metrics-store";
import { deleteResurfacingFeedbackForUser } from "@/lib/server/resurfacing-feedback-store";
import { deleteSyncDataForUser } from "@/lib/server/sync-store";
import {
  currentPushDeviceStorageMode,
  deleteMobilePushDevicesForUser,
} from "@/lib/push/mobile-push-devices";
import { logServerEvent } from "@/lib/server/structured-log";
import {
  computeOverallOk,
  notApplicableStoreResult,
  runStoreDeletion,
  safeDeletionErrorMessage,
  type AccountDeletionResult,
  type StoreDeletionResult,
} from "@/lib/server/account-deletion-contract";

export type { AccountDeletionResult, StoreDeletionResult } from "@/lib/server/account-deletion-contract";

/**
 * `deleteSyncDataForUser` reports its own real storage mode (it can be
 * postgres/filesystem/memory depending on runtime config), so this builds
 * the contract entry directly rather than forcing a mode via
 * `runStoreDeletion`.
 */
async function deleteSyncBlobsStoreResult(userId: string): Promise<StoreDeletionResult> {
  try {
    const { mode, count } = await deleteSyncDataForUser(userId);
    return {
      store: "sync_blobs",
      mode: mode === "database" ? "postgres" : mode,
      ok: true,
      count,
    };
  } catch (error) {
    return {
      store: "sync_blobs",
      mode: shouldUsePostgresStorage() ? "postgres" : "memory",
      ok: false,
      error: safeDeletionErrorMessage(error),
    };
  }
}

/**
 * Deletes every server-side store for a user, across whichever runtime mode
 * is active (Postgres / filesystem / memory), and returns an honest
 * structured result — no store's failure is silently swallowed, and no
 * store that doesn't exist in the current mode is reported as if it had
 * successfully deleted rows.
 *
 * Stores intentionally NOT part of this contract, with reasoning:
 *   - `stripe_webhook_events` (lib/server/webhook-idempotency.ts): keyed
 *     purely by Stripe event id, not by user — nothing to delete per-user.
 *   - Stripe-side subscription/customer cancellation: this function does not
 *     call out to the live Stripe API. No existing helper does this today;
 *     it is out of scope here and should be treated as a follow-up, not a
 *     silently-skipped requirement.
 *
 * `capture_attestations` IS included below, but as `not_applicable` — see
 * the inline comment for why it has no genuine per-user linkage to delete.
 */
export async function deleteUserServerData(
  userId: string,
  email: string,
): Promise<AccountDeletionResult> {
  const subjectKey = `user:${userId}`;
  const stores: StoreDeletionResult[] = [];

  const journalMode = currentJournalStorageMode();
  stores.push(
    await runStoreDeletion("journal", journalMode, () => deleteAllServerJournalEntries(userId)),
  );

  stores.push(await deleteSyncBlobsStoreResult(userId));

  const billingMode = currentBillingStorageMode();
  stores.push(
    await runStoreDeletion("billing", billingMode, () => deleteServerBilling(userId)),
  );

  const pushMode = currentPushDeviceStorageMode();
  stores.push(
    await runStoreDeletion("push_devices", pushMode, () => deleteMobilePushDevicesForUser(userId)),
  );

  if (shouldUsePostgresStorage()) {
    stores.push(
      await runStoreDeletion("sessions", "postgres", () => deleteSessionsForUserPostgres(userId)),
    );
    stores.push(
      await runStoreDeletion("auth_identity", "postgres", () =>
        deleteAuthCodesForEmailPostgres(email),
      ),
    );
  } else {
    // No server-side session table exists outside Postgres — clearing the
    // request's own session cookie (done unconditionally by the route) is
    // the full revocation mechanism in this mode.
    stores.push(notApplicableStoreResult("sessions", 0));
    stores.push(
      await runStoreDeletion("auth_identity", "memory", () =>
        deleteLocalAuthIdentity(userId, email),
      ),
    );
  }

  stores.push(
    await runStoreDeletion("api_usage", shouldUsePostgresStorage() ? "postgres" : "memory", () =>
      deleteApiUsageForSubject(subjectKey),
    ),
  );
  // openai_daily_spend — closes a previously-confirmed gap: this table was
  // not deleted at all before this change (validate-security-aplus.mjs
  // asserts this literal string is handled here).
  stores.push(
    await runStoreDeletion(
      "openai_daily_spend",
      shouldUsePostgresStorage() ? "postgres" : "memory",
      () => deleteOpenAiSpendForSubject(subjectKey),
    ),
  );
  stores.push(
    await runStoreDeletion(
      "resurfacing_events",
      shouldUsePostgresStorage() ? "postgres" : "memory",
      () => deleteResurfacingEventsForUser(userId),
    ),
  );
  stores.push(
    await runStoreDeletion(
      "resurfacing_feedback",
      shouldUsePostgresStorage() ? "postgres" : "memory",
      () => deleteResurfacingFeedbackForUser(userId),
    ),
  );

  // capture_attestations (lib/server/capture-attest-store.ts) is keyed by
  // token_jti/device_id/ip_hash/ua_hash only — there is no user_id column
  // and no reliable indirect link back to a specific account (a device can
  // be shared or reused across accounts, and attestations are short-lived
  // capture-abuse-prevention records, not user data). Reporting a fake
  // count here would misrepresent what actually happened, so this is
  // reported as not_applicable with no count.
  stores.push(notApplicableStoreResult("capture_attestations"));

  // Ephemeral, in-memory only, but included for audit completeness.
  stores.push(
    await runStoreDeletion("live_audio_sessions", "memory", () =>
      deleteLiveAudioSessionsForSubject(subjectKey),
    ),
  );

  const result: AccountDeletionResult = {
    ok: computeOverallOk(stores),
    stores,
  };

  const summary = stores
    .map((s) => `${s.store}:${s.mode}:${s.ok ? "ok" : "fail"}:${s.count ?? "-"}`)
    .join(",");
  const failedStores = stores.filter((s) => !s.ok).map((s) => s.store);

  logServerEvent("account_deletion", {
    userHash: hashUserIdForAudit(userId),
    ok: result.ok,
    stores: summary,
    failed: failedStores.length > 0 ? failedStores.join(",") : "none",
  });

  return result;
}

/**
 * Revokes all Postgres-backed sessions for a user (idempotent — a second
 * call finds nothing left to revoke). No-op outside Postgres mode, since
 * there is no server-side session table to revoke there; the request's own
 * session cookie is cleared by the route regardless of storage mode.
 */
export async function revokeAllSessionsForUser(
  userId: string,
  currentToken?: string,
): Promise<void> {
  if (!shouldUsePostgresStorage()) return;

  if (currentToken) {
    await revokeSessionPostgres(currentToken);
  }

  await deleteSessionsForUserPostgres(userId);
}

/** Short audit-log hash for a raw session token — never log the token itself. */
export function hashTokenForAudit(token: string): string {
  return hashSessionToken(token).slice(0, 12);
}
