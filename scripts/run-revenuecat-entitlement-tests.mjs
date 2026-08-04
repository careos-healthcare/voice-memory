#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";

import {
  __resetRevenueCatVerifierForTests,
  __setRevenueCatVerifierForTests,
  __verifyRevenueCatEntitlementFreshForTests,
  REVENUECAT_CACHE_TTL_MS,
  verifyRevenueCatEntitlement,
} from "../lib/server/revenuecat-verifier.ts";
import {
  __resetRevenueCatMappingsForTests,
  getRevenueCatUserMapping,
  normalizeRevenueCatAppUserId,
  upsertRevenueCatUserMapping,
} from "../lib/server/revenuecat-mapping.ts";
import {
  getAuthoritativeEntitlementState,
  resetAuthoritativeEntitlementsForTests,
} from "../lib/server/authoritative-entitlement-store.ts";
import { processRevenueCatWebhook } from "../lib/server/revenuecat-webhook-handler.ts";
import {
  authenticatedUserIdMismatchResponse,
  requireRevenueCatEntitlement,
} from "../lib/server/revenuecat-entitlement-guard.ts";

const originalSecret = process.env.REVENUECAT_SECRET_API_KEY;
process.env.REVENUECAT_SECRET_API_KEY = "test_secret";

function payload(
  expiresDate,
  id = "archive_loop_pro",
  lifetimeProductId = null,
) {
  return {
    subscriber: {
      entitlements: {
        [id]: { expires_date: expiresDate },
      },
      subscriptions: lifetimeProductId
        ? { [lifetimeProductId]: { expires_date: null } }
        : {},
    },
  };
}

function webhookEvent({
  id,
  type,
  appUserId,
  productId,
  eventAt,
  expiresAt,
}) {
  return {
    event: {
      id,
      type,
      app_user_id: appUserId,
      product_id: productId,
      entitlement_ids: ["archive_loop_pro"],
      event_timestamp_ms: eventAt,
      purchased_at_ms:
        expiresAt === null
          ? eventAt - 60_000
          : Math.min(eventAt - 60_000, expiresAt - 60_000),
      expiration_at_ms: expiresAt,
    },
  };
}

async function responseCode(response) {
  return (await response.json()).code;
}

try {
  let now = Date.parse("2026-07-25T12:00:00Z");
  let calls = 0;
  __resetRevenueCatVerifierForTests();
  __setRevenueCatVerifierForTests({
    now: () => now,
    fetch: async () => {
      calls += 1;
      return Response.json(payload("2026-07-26T12:00:00Z"));
    },
  });
  assert.equal((await verifyRevenueCatEntitlement("active-user")).active, true);
  assert.equal((await verifyRevenueCatEntitlement("active-user")).source, "cache");
  assert.equal(calls, 1, "cache hit must avoid RevenueCat within two minutes");
  now += REVENUECAT_CACHE_TTL_MS;
  await verifyRevenueCatEntitlement("active-user");
  assert.equal(calls, 2, "cache must refetch at exactly the two-minute TTL");

  now = Date.parse("2026-07-25T12:00:00Z");
  for (const [expires, expected, id] of [
    ["2026-07-25T12:00:01Z", true, "pro"],
    ["2026-07-25T11:59:59Z", false, "archive_loop_pro"],
  ]) {
    __resetRevenueCatVerifierForTests();
    __setRevenueCatVerifierForTests({
      now: () => now,
      fetch: async () => Response.json(payload(expires, id)),
    });
    const result = await verifyRevenueCatEntitlement(`parse-${String(expires)}`);
    assert.equal(result.status, "verified");
    assert.equal(result.active, expected);
  }

  __resetRevenueCatVerifierForTests();
  __setRevenueCatVerifierForTests({
    now: () => now,
    fetch: async () =>
      Response.json(
        payload(null, "archive_loop_pro", "archive_loop_pro_lifetime"),
      ),
  });
  const genuineLifetime = await verifyRevenueCatEntitlement("legacy-lifetime");
  assert.equal(genuineLifetime.status, "verified");
  assert.equal(genuineLifetime.lifetime, true);

  __resetRevenueCatVerifierForTests();
  __setRevenueCatVerifierForTests({
    now: () => now,
    fetch: async () =>
      Response.json(payload(null, "archive_loop_pro", "unknown_lifetime")),
  });
  const unknownLifetime = await verifyRevenueCatEntitlement("unknown-lifetime");
  assert.deepEqual(unknownLifetime, {
    status: "unavailable",
    reason: "malformed",
  });

  __resetRevenueCatVerifierForTests();
  __setRevenueCatVerifierForTests({
    fetch: async () =>
      Response.json({
        subscriber: {
          entitlements: { archive_loop_pro: "spoofed" },
          subscriptions: {},
        },
      }),
  });
  assert.deepEqual(await verifyRevenueCatEntitlement("malformed-entitlement"), {
    status: "unavailable",
    reason: "malformed",
  });

  __resetRevenueCatVerifierForTests();
  __setRevenueCatVerifierForTests({
    fetch: async () => new Response("", { status: 404 }),
  });
  const missing = await verifyRevenueCatEntitlement("missing-user");
  assert.equal(missing.status, "verified");
  assert.equal(missing.active, false);

  __resetRevenueCatVerifierForTests();
  __setRevenueCatVerifierForTests({
    fetch: async () => {
      const error = new Error("timed out");
      error.name = "AbortError";
      throw error;
    },
  });
  assert.deepEqual(await verifyRevenueCatEntitlement("timeout-user"), {
    status: "unavailable",
    reason: "timeout",
  });

  __resetRevenueCatVerifierForTests();
  calls = 0;
  __setRevenueCatVerifierForTests({
    fetch: async () => {
      calls += 1;
      return calls === 1
        ? Response.json(payload("2027-07-26T12:00:00Z"))
        : new Response("", { status: 503 });
    },
  });
  assert.equal((await verifyRevenueCatEntitlement("fallback-user")).active, true);
  const fallback = await __verifyRevenueCatEntitlementFreshForTests(
    "fallback-user",
  );
  assert.equal(
    fallback.source,
    "cache",
    "an unexpired successful result remains usable during upstream failure",
  );
  assert.equal(calls, 2);

  __resetRevenueCatVerifierForTests();
  __setRevenueCatVerifierForTests({
    fetch: async () => new Response("", { status: 503 }),
  });
  assert.deepEqual(await verifyRevenueCatEntitlement("failed-user"), {
    status: "unavailable",
    reason: "upstream",
  });

  __resetRevenueCatVerifierForTests();
  calls = 0;
  let release;
  const pending = new Promise((resolve) => {
    release = resolve;
  });
  __setRevenueCatVerifierForTests({
    fetch: async () => {
      calls += 1;
      await pending;
      return Response.json(payload("2027-07-26T12:00:00Z"));
    },
  });
  const concurrent = [
    verifyRevenueCatEntitlement("dedupe-user"),
    verifyRevenueCatEntitlement("dedupe-user"),
    verifyRevenueCatEntitlement("dedupe-user"),
  ];
  release();
  await Promise.all(concurrent);
  assert.equal(calls, 1, "concurrent lookups must be deduplicated");

  __resetRevenueCatMappingsForTests();
  const appUserId = "123e4567-e89b-42d3-a456-426614174000";
  await upsertRevenueCatUserMapping("user-1", appUserId);
  assert.equal((await getRevenueCatUserMapping("user-1"))?.appUserId, appUserId);
  assert.equal(
    normalizeRevenueCatAppUserId("0123456789abcdef0123456789abcdef"),
    "0123456789abcdef0123456789abcdef",
  );
  assert.equal(normalizeRevenueCatAppUserId("client-controlled-id"), null);

  resetAuthoritativeEntitlementsForTests();
  const monthStart = Date.parse("2026-07-25T12:00:00Z");
  const monthEnd = Date.parse("2026-08-25T12:00:00Z");
  const monthlyPurchase = webhookEvent({
    id: "monthly-purchase",
    type: "INITIAL_PURCHASE",
    appUserId,
    productId: "com.voicememory.app.pro.monthly",
    eventAt: monthStart,
    expiresAt: monthEnd,
  });
  assert.deepEqual(await processRevenueCatWebhook(monthlyPurchase), {
    ok: true,
    duplicate: false,
    ignored: false,
  });
  assert.equal(
    (await getAuthoritativeEntitlementState("user-1", "revenuecat"))?.status,
    "active",
  );
  const monthlyTimestamp = (
    await getAuthoritativeEntitlementState("user-1", "revenuecat")
  )?.providerEventTimestamp;
  assert.deepEqual(await processRevenueCatWebhook(monthlyPurchase), {
    ok: true,
    duplicate: true,
    ignored: false,
  });
  assert.equal(
    (
      await getAuthoritativeEntitlementState("user-1", "revenuecat")
    )?.providerEventTimestamp,
    monthlyTimestamp,
    "duplicate webhook must not mutate entitlement state",
  );

  const annualStart = Date.parse("2026-07-26T12:00:00Z");
  const annualEnd = Date.parse("2027-07-26T12:00:00Z");
  assert.equal(
    (
      await processRevenueCatWebhook(
        webhookEvent({
          id: "annual-renewal",
          type: "PRODUCT_CHANGE",
          appUserId,
          productId: "com.voicememory.app.pro.annual",
          eventAt: annualStart,
          expiresAt: annualEnd,
        }),
      )
    ).ok,
    true,
  );
  assert.equal(
    (await getAuthoritativeEntitlementState("user-1", "revenuecat"))?.periodEnd,
    new Date(annualEnd).toISOString(),
  );

  for (const [id, type, eventAt] of [
    ["expired", "EXPIRATION", annualEnd],
    ["refunded", "REFUND", annualEnd + 60_000],
    ["revoked", "REVOCATION", annualEnd + 120_000],
  ]) {
    assert.equal(
      (
        await processRevenueCatWebhook(
          webhookEvent({
            id,
            type,
            appUserId,
            productId: "com.voicememory.app.pro.annual",
            eventAt,
            expiresAt: annualEnd,
          }),
        )
      ).ok,
      true,
    );
    assert.equal(
      (await getAuthoritativeEntitlementState("user-1", "revenuecat"))?.status,
      "expired",
    );
  }

  const restoreAt = annualEnd + 180_000;
  assert.equal(
    (
      await processRevenueCatWebhook(
        webhookEvent({
          id: "restored-transfer",
          type: "TRANSFER",
          appUserId,
          productId: "com.voicememory.app.pro.annual",
          eventAt: restoreAt,
          expiresAt: restoreAt + 86_400_000,
        }),
      )
    ).ok,
    true,
  );
  assert.equal(
    (await getAuthoritativeEntitlementState("user-1", "revenuecat"))?.status,
    "active",
  );

  const authFailure = await requireRevenueCatEntitlement(null);
  assert.equal(authFailure.ok, false);
  assert.equal(authFailure.response.status, 401);
  assert.equal(await responseCode(authFailure.response), "AUTH_REQUIRED");

  const noMapping = await requireRevenueCatEntitlement("user-2", undefined, {
    getMapping: async () => null,
  });
  assert.equal(noMapping.ok, false);
  assert.equal(noMapping.response.status, 409);
  assert.equal(
    await responseCode(noMapping.response),
    "REVENUECAT_MAPPING_REQUIRED",
  );

  const mappedDependency = {
    getMapping: async () => ({
      userId: "user-1",
      appUserId,
      updatedAt: new Date(now).toISOString(),
    }),
  };
  const inactiveGuard = await requireRevenueCatEntitlement(
    "user-1",
    undefined,
    {
      ...mappedDependency,
      verify: async () => ({
        status: "verified",
        active: false,
        source: "revenuecat",
        checkedAt: now,
      }),
    },
  );
  assert.equal(inactiveGuard.ok, false);
  assert.equal(inactiveGuard.response.status, 403);
  assert.equal(
    await responseCode(inactiveGuard.response),
    "ENTITLEMENT_REQUIRED",
  );

  const unavailableGuard = await requireRevenueCatEntitlement(
    "user-1",
    undefined,
    {
      ...mappedDependency,
      verify: async () => ({ status: "unavailable", reason: "upstream" }),
    },
  );
  assert.equal(unavailableGuard.ok, false);
  assert.equal(unavailableGuard.response.status, 503);
  assert.equal(
    await responseCode(unavailableGuard.response),
    "ENTITLEMENT_VERIFICATION_UNAVAILABLE",
  );

  const mismatch = authenticatedUserIdMismatchResponse("attacker", "user-1");
  assert.equal(mismatch?.status, 403);
  assert.equal(await responseCode(mismatch), "USER_ID_MISMATCH");
  assert.equal(authenticatedUserIdMismatchResponse("user-1", "user-1"), null);

  const archiveRoute = fs.readFileSync(
    new URL("../experiments/backend/app/api/archive-synthesis/route.ts", import.meta.url),
    "utf8",
  );
  const entitlementIndex = archiveRoute.indexOf("await guardOpenAiRoute(");
  assert.ok(entitlementIndex >= 0);
  assert.ok(
    entitlementIndex <
      archiveRoute.indexOf("const cached = getCachedArchiveSynthesis("),
    "paid guard must precede synthesis cache access",
  );
  assert.ok(
    entitlementIndex < archiveRoute.indexOf("await runSynthesis("),
    "paid guard must precede OpenAI synthesis",
  );

  const linkRoute = fs.readFileSync(
    new URL("../app/api/billing/revenuecat/link/route.ts", import.meta.url),
    "utf8",
  );
  assert.match(
    linkRoute,
    /appUserId !== session\.userId\.toLowerCase\(\)/,
    "linking must reject a RevenueCat identity not derived from the session",
  );

  console.log("All RevenueCat entitlement tests passed.");
} finally {
  __resetRevenueCatVerifierForTests();
  __resetRevenueCatMappingsForTests();
  resetAuthoritativeEntitlementsForTests();
  if (originalSecret === undefined) delete process.env.REVENUECAT_SECRET_API_KEY;
  else process.env.REVENUECAT_SECRET_API_KEY = originalSecret;
}
