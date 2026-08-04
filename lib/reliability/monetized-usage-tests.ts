import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";

import {
  readUsageAllowances,
  UsageAllowanceConfigurationError,
  validateProductionUsageAllowances,
} from "@/lib/server/usage-allowance-config";
import {
  MONETIZATION_PLAN_IDS,
  USAGE_METER_IDS,
} from "@/lib/server/monetization-policy";
import {
  commitUsageReservation,
  releaseUsageReservation,
  reserveUsage,
  resetUsageReservationsForTests,
  summarizeCommittedUsageByPlan,
} from "@/lib/server/usage-reservation-store";
import {
  getAuthoritativeEntitlementState,
  resetAuthoritativeEntitlementsForTests,
  upsertAuthoritativeEntitlementState,
} from "@/lib/server/authoritative-entitlement-store";
import {
  __resetRevenueCatMappingsForTests,
  upsertRevenueCatUserMapping,
} from "@/lib/server/revenuecat-mapping";
import {
  authorizeRevenueCatWebhook,
  processRevenueCatWebhook,
} from "@/lib/server/revenuecat-webhook-handler";
import { requireMonetizedAccess } from "@/lib/server/monetized-access-guard";
import { validateProductionEnv } from "@/lib/server/production-env";

export async function runMonetizedUsageTests(): Promise<{
  failures: string[];
}> {
  const failures: string[] = [];
  const check = async (name: string, fn: () => void | Promise<void>) => {
    try {
      await fn();
    } catch (error) {
      failures.push(
        `${name}: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  };
  const savedDatabase = process.env.DATABASE_URL;
  delete process.env.DATABASE_URL;
  resetUsageReservationsForTests();
  resetAuthoritativeEntitlementsForTests();
  __resetRevenueCatMappingsForTests();

  const base = {
    userId: "test-user",
    planId: "free" as const,
    capabilityId: "remoteTranscription" as const,
    meterId: "remoteTranscriptionSeconds" as const,
    periodStart: new Date("2026-08-01T00:00:00Z"),
    periodEnd: new Date("2026-09-01T00:00:00Z"),
    units: 6,
    allowance: 10,
    idempotencyKey: "opaque-request-one",
  };

  await check("configuration is mandatory and strictly typed", () => {
    assert.throws(
      () => readUsageAllowances(""),
      UsageAllowanceConfigurationError,
    );
    assert.throws(
      () => readUsageAllowances('{"free":{"remoteTranscriptionSeconds":1.5}}'),
      UsageAllowanceConfigurationError,
    );
    assert.equal(
      readUsageAllowances('{"free":{"remoteTranscriptionSeconds":10}}').free
        ?.remoteTranscriptionSeconds,
      10,
    );
    assert.ok(validateProductionUsageAllowances("{}").length > 0);
  });

  await check(
    "signed RevenueCat events update authoritative state idempotently",
    async () => {
      const token = "r".repeat(40);
      assert.equal(authorizeRevenueCatWebhook(`Bearer ${token}`, token), null);
      assert.equal(
        authorizeRevenueCatWebhook("Bearer wrong", token)?.ok,
        false,
      );
      const userId = "a".repeat(32);
      await upsertRevenueCatUserMapping(userId, userId);
      const event = {
        event: {
          id: "rc-event-1",
          type: "INITIAL_PURCHASE",
          app_user_id: userId,
          entitlement_ids: ["archive_loop_pro"],
          event_timestamp_ms: Date.parse("2026-08-01T01:00:00Z"),
          purchased_at_ms: Date.parse("2026-08-01T00:00:00Z"),
          expiration_at_ms: Date.parse("2026-09-01T00:00:00Z"),
        },
      };
      assert.deepEqual(await processRevenueCatWebhook(event), {
        ok: true,
        duplicate: false,
        ignored: false,
      });
      assert.deepEqual(await processRevenueCatWebhook(event), {
        ok: true,
        duplicate: true,
        ignored: false,
      });
      await processRevenueCatWebhook({
        event: {
          ...event.event,
          id: "rc-event-older",
          type: "EXPIRATION",
          event_timestamp_ms: Date.parse("2026-07-31T23:00:00Z"),
        },
      });
      assert.equal(
        (await getAuthoritativeEntitlementState(userId, "revenuecat"))?.status,
        "active",
      );
      await processRevenueCatWebhook({
        event: {
          ...event.event,
          id: "rc-event-refund",
          type: "REFUND",
          event_timestamp_ms: Date.parse("2026-08-02T00:00:00Z"),
        },
      });
      assert.equal(
        (await getAuthoritativeEntitlementState(userId, "revenuecat"))?.status,
        "expired",
      );
      await processRevenueCatWebhook({
        event: {
          ...event.event,
          id: "rc-event-ordinary-nonrenewing",
          type: "NON_RENEWING_PURCHASE",
          product_id: "ordinary_nonrenewing_product",
          expiration_at_ms: null,
          event_timestamp_ms: Date.parse("2026-08-03T00:00:00Z"),
        },
      });
      assert.equal(
        (await getAuthoritativeEntitlementState(userId, "revenuecat"))?.planId,
        "pro_subscription",
      );
      await processRevenueCatWebhook({
        event: {
          ...event.event,
          id: "rc-event-legacy-lifetime",
          type: "NON_RENEWING_PURCHASE",
          product_id: "archive_loop_pro_lifetime",
          expiration_at_ms: null,
          event_timestamp_ms: Date.parse("2026-08-04T00:00:00Z"),
        },
      });
      assert.equal(
        (await getAuthoritativeEntitlementState(userId, "revenuecat"))?.planId,
        "legacy_grandfathered",
      );
    },
  );

  await check(
    "central guard denies duplicates before provider execution",
    async () => {
      resetUsageReservationsForTests();
      const userId = "b".repeat(32);
      await upsertAuthoritativeEntitlementState({
        userId,
        provider: "stripe",
        status: "active",
        planId: "pro_subscription",
        periodStart: new Date("2026-08-01T00:00:00Z"),
        periodEnd: new Date("2026-09-01T00:00:00Z"),
        providerEventTimestamp: new Date("2026-08-01T00:00:00Z"),
      });
      const fixture = Object.fromEntries(
        MONETIZATION_PLAN_IDS.map((plan) => [
          plan,
          Object.fromEntries(USAGE_METER_IDS.map((meter) => [meter, 10])),
        ]),
      );
      process.env.VOICEMEMORY_USAGE_ALLOWANCES_JSON = JSON.stringify(fixture);
      const first = await requireMonetizedAccess({
        userId,
        capabilityId: "deepArchiveSynthesis",
        idempotencyKey: "central-guard-one",
        now: new Date("2026-08-02T00:00:00Z"),
      });
      assert.equal(first.ok, true);
      const duplicate = await requireMonetizedAccess({
        userId,
        capabilityId: "deepArchiveSynthesis",
        idempotencyKey: "central-guard-one",
        now: new Date("2026-08-02T00:00:00Z"),
      });
      assert.equal(duplicate.ok, false);
      if (!duplicate.ok) {
        assert.equal(
          (await duplicate.response.json()).code,
          "REQUEST_IN_PROGRESS",
        );
      }
      if (first.ok && first.ctx.reservation) {
        await releaseUsageReservation(first.ctx.reservation.reservationId);
      }
    },
  );

  await check(
    "authoritative revocation cannot be reopened by a live read",
    async () => {
      const userId = "c".repeat(32);
      await upsertRevenueCatUserMapping(userId, userId);
      await upsertAuthoritativeEntitlementState({
        userId,
        provider: "revenuecat",
        status: "expired",
        planId: "free",
        periodStart: new Date("2026-07-01T00:00:00Z"),
        periodEnd: new Date("2026-08-01T00:00:00Z"),
        providerEventTimestamp: new Date("2026-08-01T01:00:00Z"),
      });
      const result = await requireMonetizedAccess({
        userId,
        capabilityId: "deepArchiveSynthesis",
        idempotencyKey: "revoked-access",
        now: new Date("2026-08-02T00:00:00Z"),
      });
      assert.equal(result.ok, false);
      if (!result.ok) {
        assert.equal(
          (await result.response.json()).code,
          "ENTITLEMENT_REQUIRED",
        );
      }
    },
  );

  await check("reservation idempotency and concurrent allowance", async () => {
    const [first, duplicate] = await Promise.all([
      reserveUsage(base),
      reserveUsage(base),
    ]);
    assert.equal(first.allowed, true);
    assert.equal(duplicate.allowed, true);
    if (!first.allowed || !duplicate.allowed) return;
    assert.equal(
      first.reservation.reservationId,
      duplicate.reservation.reservationId,
    );
    const denied = await reserveUsage({
      ...base,
      idempotencyKey: "two",
      units: 5,
    });
    assert.equal(denied.allowed, false);
  });

  await check(
    "release restores capacity and commit records actual units",
    async () => {
      const first = await reserveUsage({ ...base, idempotencyKey: "release" });
      assert.equal(first.allowed, false);
      const existing = await reserveUsage(base);
      assert.equal(existing.allowed, true);
      if (!existing.allowed) return;
      await releaseUsageReservation(existing.reservation.reservationId);
      const replacement = await reserveUsage({
        ...base,
        idempotencyKey: "replacement",
        units: 10,
      });
      assert.equal(replacement.allowed, true);
      if (!replacement.allowed) return;
      await commitUsageReservation(replacement.reservation.reservationId, 8, {
        providerInputUnits: 120,
        providerOutputUnits: 45,
        audioSeconds: 8,
        safeResultCode: "provider_completed",
      });
      const committed = await reserveUsage({
        ...base,
        idempotencyKey: "replacement",
        units: 10,
      });
      assert.equal(committed.allowed, true);
      if (committed.allowed) {
        assert.equal(committed.duplicate, true);
        assert.equal(committed.reservation.unitsCommitted, 8);
        assert.equal(committed.reservation.providerInputUnits, 120);
        assert.equal(committed.reservation.providerOutputUnits, 45);
        assert.equal(committed.reservation.audioSeconds, 8);
        assert.equal(
          committed.reservation.safeResultCode,
          "provider_completed",
        );
        assert.match(
          committed.reservation.policyVersion,
          /^\d{4}-\d{2}-\d{2}$/,
        );
      }
      const report = await summarizeCommittedUsageByPlan(
        new Date("2026-07-01T00:00:00Z"),
        new Date("2026-10-01T00:00:00Z"),
      );
      assert.equal(report[0]?.committedUnits, 8);
    },
  );

  await check("billing period reset is isolated", async () => {
    const next = await reserveUsage({
      ...base,
      periodStart: new Date("2026-09-01T00:00:00Z"),
      periodEnd: new Date("2026-10-01T00:00:00Z"),
      idempotencyKey: "replacement",
      units: 10,
    });
    assert.equal(next.allowed, true);
  });

  await check("schema, deletion, privacy, and route guards", async () => {
    const store = await readFile(
      path.join(process.cwd(), "lib/server/usage-reservation-store.ts"),
      "utf8",
    );
    assert.ok(store.includes("pg_advisory_xact_lock"));
    assert.ok(store.includes("BEGIN"));
    const migration = await readFile(
      path.join(process.cwd(), "docs/sql/010_monetized_usage.sql"),
      "utf8",
    );
    for (const banned of [
      "transcript",
      "prompt",
      "entry_id",
      "blob_id",
      "audio_bytes",
    ]) {
      assert.equal(new RegExp(`\\b${banned}\\b`, "i").test(migration), false);
    }
    const migrationRunner = await readFile(
      path.join(process.cwd(), "scripts/activate-monetized-usage-schema.mjs"),
      "utf8",
    );
    for (const required of [
      'client.query("BEGIN")',
      "client.query(sql)",
      'client.query("COMMIT")',
      "billing_entitlement_sources",
      "usage_reservations",
    ])
      assert.ok(migrationRunner.includes(required));
    const deletion = await readFile(
      path.join(
        process.cwd(),
        "lib/server/privacy/user-data-deletion-registry.ts",
      ),
      "utf8",
    );
    assert.ok(deletion.includes('"usage-reservations", "usage_reservations"'));
    assert.ok(
      deletion.includes(
        '"billing-entitlement-sources", "billing_entitlement_sources"',
      ),
    );
    const accessGuard = await readFile(
      path.join(process.cwd(), "lib/server/monetized-access-guard.ts"),
      "utf8",
    );
    const unitMeter = await readFile(
      path.join(process.cwd(), "lib/server/unit-economics-meter.ts"),
      "utf8",
    );
    assert.match(
      unitMeter,
      /meterOpenAiChatUsage[\s\S]*await commitOpenAiChatReservation\(/,
    );
    assert.match(
      unitMeter,
      /meterBestEffort[\s\S]*await commitMonetizedUsage\(/,
    );
    const guardedRoutes = [
      "transcribe",
      "analyze",
    ];
    const policyRoutes = [
      ...accessGuard.matchAll(/\["\/api\/([^"]+)",\s*"[^"]+"\]/g),
    ]
      .map((match) => match[1])
      .sort();
    assert.deepEqual([...guardedRoutes].sort(), policyRoutes);
    const provenCommitSignals = [
      "commitUsageReservation(",
      "meterConfiguredOpenAiChatUsage({",
      "meterOpenAiChatUsage({",
      "meterBestEffort({",
    ];
    for (const route of guardedRoutes) {
      const source = await readFile(
        path.join(process.cwd(), "app/api", route, "route.ts"),
        "utf8",
      );
      const postSource = source.slice(
        source.indexOf("export async function POST"),
      );
      const guardIndex = postSource.indexOf("await guardOpenAiRoute");
      assert.ok(guardIndex >= 0, `${route} lacks access guard`);
      const providerIndexes = [
        "await getOpenAIClient()",
        "await openai.",
        "await client.",
        "await generateDocumentIngestion",
        "await generateMorningBriefing",
        "await generateLifeStoryReplay",
      ]
        .map((needle) => postSource.indexOf(needle))
        .filter((index) => index >= 0);
      assert.ok(
        providerIndexes.length === 0 ||
          guardIndex < Math.min(...providerIndexes),
        `${route} guard follows provider call`,
      );
      assert.ok(
        postSource.includes("releaseUsageReservation"),
        `${route} does not release failed reservations`,
      );
      assert.ok(
        provenCommitSignals.some((signal) => source.includes(signal)),
        `${route} does not commit a successful provider operation`,
      );
    }
    const transcribeRoute = await readFile(
      path.join(process.cwd(), "app/api/transcribe/route.ts"),
      "utf8",
    );
    assert.match(
      transcribeRoute,
      /transcriptionDurationMilliseconds\(\s*vendorDuration,\s*undefined,\s*\)/,
    );
    const vaultRecoveryProcess = await readFile(
      path.join(process.cwd(), "lib/live-audio/vault-recovery-process.ts"),
      "utf8",
    );
    assert.match(
      vaultRecoveryProcess,
      /const durationSeconds = durationSecondsFromVault\(decrypted\)/,
    );
    const liveSession = await readFile(
      path.join(process.cwd(), "experiments/backend/app/api/live-audio/session/route.ts"),
      "utf8",
    );
    const liveProxy = await readFile(
      path.join(process.cwd(), "lib/live-audio/ws-proxy-connection.ts"),
      "utf8",
    );
    assert.ok(liveSession.includes("guardLiveAudioSessionRoute"));
    assert.ok(liveProxy.includes("commitUsageReservation"));
    assert.ok(liveProxy.includes("releaseUsageReservation"));
  });

  await check("production readiness validates server controls", () => {
    const fixture = Object.fromEntries(
      MONETIZATION_PLAN_IDS.map((plan) => [
        plan,
        Object.fromEntries(USAGE_METER_IDS.map((meter) => [meter, 10])),
      ]),
    );
    process.env.VOICEMEMORY_USAGE_ALLOWANCES_JSON = JSON.stringify(fixture);
    process.env.REVENUECAT_SECRET_API_KEY = "secret";
    process.env.REVENUECAT_WEBHOOK_AUTH_TOKEN = "w".repeat(40);
    for (const name of [
      "VOICEMEMORY_DAILY_TRANSCRIBE_LIMIT",
      "VOICEMEMORY_MINUTE_TRANSCRIBE_LIMIT",
      "VOICEMEMORY_DAILY_ANALYZE_LIMIT",
      "VOICEMEMORY_MINUTE_ANALYZE_LIMIT",
      "VOICEMEMORY_DAILY_ATMOSPHERE_LIMIT",
      "VOICEMEMORY_MINUTE_ATMOSPHERE_LIMIT",
      "VOICEMEMORY_DAILY_ATTEST_LIMIT",
      "VOICEMEMORY_MINUTE_ATTEST_LIMIT",
      "VOICEMEMORY_DAILY_LIVE_AUDIO_LIMIT",
      "VOICEMEMORY_MINUTE_LIVE_AUDIO_LIMIT",
    ])
      process.env[name] = "10";
    const report = validateProductionEnv({ strict: true });
    assert.equal(
      report.issues.some((issue) =>
        [
          "USAGE_ALLOWANCES",
          "USAGE_RATE_LIMITS",
          "REVENUECAT_SECRET_API_KEY",
          "REVENUECAT_WEBHOOK_AUTH_TOKEN",
        ].includes(issue.code),
      ),
      false,
    );
  });

  if (savedDatabase === undefined) delete process.env.DATABASE_URL;
  else process.env.DATABASE_URL = savedDatabase;
  return { failures };
}
