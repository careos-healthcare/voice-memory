import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { randomUUID } from "node:crypto";

import {
  computeOverallOk,
  notApplicableStoreResult,
  runStoreDeletion,
  type StoreDeletionResult,
} from "@/lib/server/account-deletion-contract";
import { deleteUserServerData, revokeAllSessionsForUser } from "@/lib/server/account-deletion";
import { getUserById } from "@/lib/server/auth-store";
import { readAuthStore, writeAuthStore } from "@/lib/server/auth-storage";
import { checkAndRecordApiUsage, peekDayUsage } from "@/lib/server/api-usage-store";
import {
  getServerBillingRecord,
  upsertServerBillingRecord,
} from "@/lib/server/billing-entitlements";
import { shouldUsePostgresStorage } from "@/lib/server/db";
import { resolveDataPath, removeDataPath } from "@/lib/server/data-path";
import { exportServerJournal, upsertServerJournalEntries } from "@/lib/server/journal-store";
import { readEncryptedBlobs, upsertEncryptedBlobs } from "@/lib/server/sync-store";
import {
  consumeLiveAudioSession,
  registerLiveAudioSession,
} from "@/lib/live-audio/session-store";
import {
  getFcmTokenForDevice,
  upsertMobilePushDevice,
} from "@/lib/push/mobile-push-devices";
import { peekOpenAiSpend, reserveOpenAiSpend } from "@/lib/server/openai-spend-store";
import {
  fetchResurfacingFeedbackSummary,
  insertResurfacingFeedback,
} from "@/lib/server/resurfacing-feedback-store";
import {
  aggregateResurfacingMetrics,
  recordResurfacingEvent,
} from "@/lib/server/resurfacing-metrics-store";
import type { JournalEntry } from "@/types/journal";

/**
 * Server account-deletion contract tests. Runs against whichever runtime
 * mode is active in this process:
 *   - No `DATABASE_URL` (the default for local/test runs): journal, billing,
 *     push devices, api usage, OpenAI spend, and resurfacing stores all run
 *     in-memory (they have no filesystem branch at all); sync blobs and auth
 *     identity run on the filesystem branch (dev default) — so this single
 *     run already exercises both the "memory" and "filesystem" halves of the
 *     contract for the stores that actually have one.
 *   - `DATABASE_URL` set: the Postgres-only assertions below additionally
 *     run; they are skipped (not failed) otherwise, matching this repo's
 *     existing convention of gating Postgres-only checks on the env var
 *     rather than requiring a live database for every test run.
 */

function sampleJournalEntry(id: string): JournalEntry {
  return {
    id,
    createdAt: new Date().toISOString(),
    transcript: "account-deletion-test transcript",
    reflection: {
      mood: "calm",
      emotionalIntensity: 1,
      recurringThemes: [],
      hiddenConcern: "",
      positiveSignal: "",
      recommendation: "",
    },
    durationSeconds: 5,
  };
}

async function seedAllStoresForUser(userId: string, email: string): Promise<void> {
  await upsertServerJournalEntries(userId, [{ entry: sampleJournalEntry(`${userId}-entry`) }]);
  await upsertEncryptedBlobs(userId, [
    {
      id: `${userId}-blob`,
      type: "settings",
      encrypted: { ciphertext: "cGxhY2Vob2xkZXI=", iv: "aXY=", version: 1 },
      updatedAt: new Date().toISOString(),
      byteLength: 16,
    },
  ]);
  await upsertServerBillingRecord({
    userId,
    status: "active",
    tier: "pro",
    stripeCustomerId: `cus_${userId}`,
  });
  await upsertMobilePushDevice({
    userId,
    deviceId: `${userId}-device`,
    platform: "ios",
    fcmToken: `token-${userId}`,
  });
  await checkAndRecordApiUsage(`user:${userId}`, "transcribe");
  await reserveOpenAiSpend(`user:${userId}`, 100, 100_000);
  await insertResurfacingFeedback({
    userId,
    feedbackType: "that_fits",
    phraseKeyHash: `phrase-${userId}`,
    feedbackWeight: 1,
  });
  await recordResurfacingEvent({ subjectKey: `user:${userId}`, userId, eventName: "callback_shown" });
  await registerLiveAudioSession({
    jti: `${userId}-jti`,
    sessionId: `${userId}-session`,
    subject: `user:${userId}`,
    ipHash: "ip-hash",
    uaHash: "ua-hash",
  });

  // Local auth identity — write directly rather than going through the
  // rate-limited issue-code flow, so this test is independent of the auth
  // resend cooldown.
  if (!shouldUsePostgresStorage()) {
    const store = readAuthStore();
    store.usersByEmail[email] = { id: userId, email, createdAt: new Date().toISOString() };
    writeAuthStore(store);
  }
}

async function assertUserDataGone(userId: string): Promise<void> {
  assert.equal((await exportServerJournal(userId)).length, 0, "journal must be empty");
  assert.equal((await readEncryptedBlobs(userId)).length, 0, "sync blobs must be empty");
  assert.equal(await getServerBillingRecord(userId), null, "billing record must be gone");
  assert.equal(
    await getFcmTokenForDevice(`${userId}-device`),
    null,
    "push device must be gone",
  );
  assert.equal(
    (await peekDayUsage(`user:${userId}`)).transcribe,
    0,
    "api usage must be reset",
  );
  assert.equal(await peekOpenAiSpend(`user:${userId}`), 0, "openai spend must be reset");

  const feedback = await fetchResurfacingFeedbackSummary(userId);
  assert.deepEqual(feedback.acceptanceBoosts, {}, "resurfacing feedback must be gone");

  const events = await aggregateResurfacingMetrics(`user:${userId}`);
  assert.equal(events.callback_shown, 0, "resurfacing events must be gone");

  const liveAudio = await consumeLiveAudioSession({
    jti: `${userId}-jti`,
    ipHash: "ip-hash",
    uaHash: "ua-hash",
  });
  assert.equal(liveAudio.ok, false, "live audio session must no longer be consumable");

  if (!shouldUsePostgresStorage()) {
    assert.equal(await getUserById(userId), null, "local auth identity must be gone");
  }
}

async function assertUserDataIntact(userId: string, email: string): Promise<void> {
  assert.equal((await exportServerJournal(userId)).length, 1, "journal must be untouched");
  assert.equal((await readEncryptedBlobs(userId)).length, 1, "sync blobs must be untouched");
  assert.ok(await getServerBillingRecord(userId), "billing record must be untouched");
  assert.equal(
    await getFcmTokenForDevice(`${userId}-device`),
    `token-${userId}`,
    "push device must be untouched",
  );
  assert.ok(
    (await peekDayUsage(`user:${userId}`)).transcribe >= 1,
    "api usage must be untouched",
  );
  assert.ok(
    (await peekOpenAiSpend(`user:${userId}`)) > 0,
    "openai spend must be untouched",
  );

  if (!shouldUsePostgresStorage()) {
    const user = await getUserById(userId);
    assert.ok(user, "local auth identity must be untouched");
    assert.equal(user?.email, email);
  }
}

export async function runAccountDeletionTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];

  async function check(name: string, fn: () => void | Promise<void>): Promise<void> {
    try {
      await fn();
    } catch (error) {
      failures.push(`${name}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  await check(
    "deletion removes every owned row while a second user's data in every store stays intact",
    async () => {
      const userA = `del-a-${randomUUID()}`;
      const userB = `del-b-${randomUUID()}`;
      const emailA = `${userA}@example.test`;
      const emailB = `${userB}@example.test`;

      await seedAllStoresForUser(userA, emailA);
      await seedAllStoresForUser(userB, emailB);

      const result = await deleteUserServerData(userA, emailA);
      assert.equal(result.ok, true, `expected full success, got: ${JSON.stringify(result.stores)}`);
      for (const s of result.stores) {
        assert.equal(s.ok, true, `store ${s.store} reported failure: ${s.error}`);
      }

      await assertUserDataGone(userA);
      await assertUserDataIntact(userB, emailB);
    },
  );

  await check("repeated deletion is idempotent and never throws", async () => {
    const userId = `del-idem-${randomUUID()}`;
    const email = `${userId}@example.test`;
    await seedAllStoresForUser(userId, email);

    const first = await deleteUserServerData(userId, email);
    assert.equal(first.ok, true);

    const second = await deleteUserServerData(userId, email);
    assert.equal(second.ok, true, "second deletion must still report ok");
    for (const s of second.stores) {
      assert.equal(s.ok, true, `store ${s.store} must not fail on a no-op re-delete`);
      if (s.count !== undefined) {
        assert.equal(s.count, 0, `store ${s.store} must report 0 removed on second call`);
      }
    }

    await assertUserDataGone(userId);
  });

  await check("stores every store's mode and includes required stores", async () => {
    const userId = `del-shape-${randomUUID()}`;
    const email = `${userId}@example.test`;
    await seedAllStoresForUser(userId, email);

    const result = await deleteUserServerData(userId, email);
    const byName = Object.fromEntries(result.stores.map((s) => [s.store, s]));

    for (const required of ["journal", "sync_blobs", "sessions", "billing", "push_devices"]) {
      assert.ok(byName[required], `missing required store in contract result: ${required}`);
      assert.ok(
        ["postgres", "filesystem", "memory", "not_applicable"].includes(byName[required].mode),
        `store ${required} has an invalid mode`,
      );
    }

    // Gap fix: openai_daily_spend must actually be part of the contract, not just mentioned in a comment.
    assert.ok(byName["openai_daily_spend"], "openai_daily_spend must be part of the deletion contract");

    // Not user-linkable — must be honestly reported as not_applicable, with no fabricated count.
    assert.equal(byName["capture_attestations"]?.mode, "not_applicable");
    assert.equal(byName["capture_attestations"]?.count, undefined);
  });

  await check(
    "a simulated store failure is reported honestly and does not flip unrelated stores to failed",
    async () => {
      // This exercises the exact mechanism deleteUserServerData is built
      // from (lib/server/account-deletion-contract.ts): every store call is
      // wrapped individually, so one throwing store never corrupts another
      // store's result or the overall pass/fail computation.
      const throwing = await runStoreDeletion("journal", "memory", () => {
        throw new Error("simulated journal deletion failure");
      });
      assert.equal(throwing.ok, false);
      assert.match(throwing.error ?? "", /simulated journal deletion failure/);

      const healthy = await runStoreDeletion("billing", "memory", () => 3);
      assert.equal(healthy.ok, true);
      assert.equal(healthy.count, 3);

      const stores: StoreDeletionResult[] = [
        throwing,
        healthy,
        notApplicableStoreResult("capture_attestations"),
      ];
      // journal is required -> overall must be false even though billing succeeded.
      assert.equal(computeOverallOk(stores), false);

      // Retrying afterward (failure fixed) must complete the remaining cleanup honestly.
      const retried = await runStoreDeletion("journal", "memory", () => 1);
      assert.equal(retried.ok, true);
      const retriedStores: StoreDeletionResult[] = [retried, healthy];
      assert.equal(computeOverallOk(retriedStores), true);
    },
  );

  await check(
    "overall ok is unaffected by a failing best-effort (non-required) store",
    async () => {
      const stores: StoreDeletionResult[] = [
        { store: "journal", mode: "memory", ok: true, count: 1 },
        { store: "sync_blobs", mode: "memory", ok: true, count: 0 },
        { store: "sessions", mode: "not_applicable", ok: true },
        { store: "billing", mode: "memory", ok: true, count: 0 },
        { store: "push_devices", mode: "memory", ok: true, count: 0 },
        { store: "resurfacing_events", mode: "memory", ok: false, error: "simulated" },
      ];
      assert.equal(computeOverallOk(stores), true);
    },
  );

  await check(
    "after deletion, the user's local auth identity can no longer resolve a session",
    async () => {
      if (shouldUsePostgresStorage()) return; // covered by the Postgres block below.
      const userId = `del-session-${randomUUID()}`;
      const email = `${userId}@example.test`;
      const store = readAuthStore();
      store.usersByEmail[email] = { id: userId, email, createdAt: new Date().toISOString() };
      writeAuthStore(store);

      assert.ok(await getUserById(userId), "user must resolve before deletion");
      await deleteUserServerData(userId, email);
      assert.equal(
        await getUserById(userId),
        null,
        "a session token for this user must no longer resolve after deletion",
      );
    },
  );

  await check("revokeAllSessionsForUser is a safe no-op outside Postgres mode", async () => {
    if (shouldUsePostgresStorage()) return;
    // Must not throw even with no session table to act on.
    await revokeAllSessionsForUser(`no-such-user-${randomUUID()}`, "some-token");
  });

  await check("filesystem path safety: traversal outside the data root is rejected", () => {
    assert.throws(() => resolveDataPath("sync", "..", "..", "etc", "passwd"));
    assert.throws(() => resolveDataPath("..", "outside"));
  });

  await check("filesystem path safety: deleting a missing path is a safe no-op", () => {
    const removed = removeDataPath("sync", `does-not-exist-${randomUUID()}`);
    assert.equal(removed, false);
  });

  await check(
    "filesystem path safety: a symlink under the data root is unlinked, not followed",
    () => {
      const dataDir = resolveDataPath("sync-symlink-test");
      fs.mkdirSync(dataDir, { recursive: true });

      const outsideDir = fs.mkdtempSync(path.join(os.tmpdir(), "vm-outside-"));
      const sentinelFile = path.join(outsideDir, "sentinel.txt");
      fs.writeFileSync(sentinelFile, "must survive");

      const linkPath = path.join(dataDir, "escape-link");
      fs.symlinkSync(outsideDir, linkPath, "dir");

      const removed = removeDataPath("sync-symlink-test", "escape-link");
      assert.equal(removed, true);
      assert.ok(fs.existsSync(sentinelFile), "target of the symlink must not be deleted");
      assert.ok(!fs.existsSync(linkPath), "the symlink itself must be gone");

      fs.rmSync(dataDir, { recursive: true, force: true });
      fs.rmSync(outsideDir, { recursive: true, force: true });
    },
  );

  if (shouldUsePostgresStorage()) {
    await check("[postgres] deletion removes rows while a second user's rows remain", async () => {
      const userA = `del-pg-a-${randomUUID()}`;
      const userB = `del-pg-b-${randomUUID()}`;
      const emailA = `${userA}@example.test`;
      const emailB = `${userB}@example.test`;

      await seedAllStoresForUser(userA, emailA);
      await seedAllStoresForUser(userB, emailB);

      const result = await deleteUserServerData(userA, emailA);
      assert.equal(result.ok, true, `expected full success, got: ${JSON.stringify(result.stores)}`);
      for (const s of result.stores) {
        assert.notEqual(s.mode, "filesystem", "postgres runtime must not report filesystem mode");
      }

      await assertUserDataGone(userA);
      await assertUserDataIntact(userB, emailB);

      const second = await deleteUserServerData(userA, emailA);
      assert.equal(second.ok, true, "second postgres deletion must still be idempotent");
    });
  }

  return { failures };
}
