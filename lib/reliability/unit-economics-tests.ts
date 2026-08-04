import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";

import {
  appendThresholdBreach,
  breachesForRollup,
  recordRollupBreaches,
  resetUnitEconomicsBreachMemoryForTests,
} from "@/lib/server/unit-economics-breach-store";
import {
  calculateCostMicroUsd,
  subjectKeyVersion,
  utcDay,
  type UsageLedgerRow,
} from "@/lib/server/unit-economics-domain";
import {
  calculateDailyRollup,
  reconcileDailySubjectRollup,
  recordMoneyLedgerRow,
} from "@/lib/server/unit-economics-engine";
import {
  appendUsageLedgerRow,
  listUsageLedgerRows,
  resetUnitEconomicsLedgerMemoryForTests,
} from "@/lib/server/unit-economics-ledger-store";
import {
  insertPricingCatalog,
  resetUnitEconomicsPricingMemoryForTests,
  selectPricingCatalog,
} from "@/lib/server/unit-economics-pricing-store";
import { resetUnitEconomicsRollupMemoryForTests } from "@/lib/server/unit-economics-rollup-store";
import {
  createEconomicsBreachDedupKey,
  createEconomicsBreachKey,
  createEconomicsEventKey,
  createEconomicsSubjectKey,
  createEconomicsSubjectKeysForRotation,
} from "@/lib/server/unit-economics-subject-key";
import { DATABASE_SCHEMA_STATEMENTS } from "@/lib/server/db";
import { REQUIRED_INDEXES, REQUIRED_TABLES } from "@/lib/server/migration-manifest";
import { assertProductionUnitEconomicsIsDurable } from "@/lib/server/unit-economics-config";
import { authorizeUnitEconomicsCron } from "@/lib/server/unit-economics-cron";
import {
  extractOpenAiTokenClasses,
  exactUtf8Bytes,
  meterBestEffort,
  meterMoneyBestEffort,
  meterOpenAiChatUsage,
  transcriptionDurationMilliseconds,
  vendorRequestId,
} from "@/lib/server/unit-economics-meter";
import {
  loadPricingCatalog,
  pricingCoverageErrors,
  REQUIRED_PRICING_PAIRS,
} from "@/lib/server/unit-economics-pricing-catalog";
import { getUnitEconomicsReadiness } from "@/lib/server/unit-economics-readiness";
import { parseFinanceRevenueInput } from "@/lib/server/unit-economics-revenue-input";
import {
  recordStorageFootprintRows,
} from "@/lib/server/unit-economics-storage-reconcile";
import {
  serializeJsonBody,
  serializedJsonResponse,
} from "@/lib/server/serialized-json-response";

export async function runUnitEconomicsTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];
  const envNames = [
    "NODE_ENV",
    "DATABASE_URL",
    "VOICEMEMORY_UNIT_ECONOMICS_HMAC_ACTIVE_VERSION",
    "VOICEMEMORY_UNIT_ECONOMICS_HMAC_KEY_V1",
    "VOICEMEMORY_UNIT_ECONOMICS_HMAC_KEY_V2",
    "VOICEMEMORY_UNIT_ECONOMICS_ALLOW_DEV_FALLBACK",
    "VOICEMEMORY_UNIT_ECONOMICS_ENABLED",
    "VOICEMEMORY_UNIT_ECONOMICS_PRICING_REQUIRED",
    "VOICEMEMORY_UNIT_ECONOMICS_PRICING_CATALOG_PATH",
    "CRON_SECRET",
  ] as const;
  const saved = Object.fromEntries(envNames.map((name) => [name, process.env[name]]));
  const check = async (name: string, test: () => void | Promise<void>) => {
    try {
      await test();
    } catch (error) {
      failures.push(`${name}: ${error instanceof Error ? error.message : String(error)}`);
    }
  };

  try {
    (process.env as Record<string, string | undefined>).NODE_ENV = "test";
    delete process.env.DATABASE_URL;
    process.env.VOICEMEMORY_UNIT_ECONOMICS_HMAC_ACTIVE_VERSION = "2";
    process.env.VOICEMEMORY_UNIT_ECONOMICS_HMAC_KEY_V1 = Buffer.alloc(32, 1).toString("base64");
    process.env.VOICEMEMORY_UNIT_ECONOMICS_HMAC_KEY_V2 = Buffer.alloc(32, 2).toString("base64");
    delete process.env.VOICEMEMORY_UNIT_ECONOMICS_ALLOW_DEV_FALLBACK;
    resetUnitEconomicsPricingMemoryForTests();
    resetUnitEconomicsLedgerMemoryForTests();
    resetUnitEconomicsRollupMemoryForTests();
    resetUnitEconomicsBreachMemoryForTests();

    const rawPii = "person@example.com/session/raw-entry-123";
    const subjectKey = createEconomicsSubjectKey("user", rawPii);
    const occurredAt = new Date("2026-07-26T10:00:00.000Z");
    const day = utcDay(occurredAt);

    await check("HMAC rotation, format, and privacy", () => {
      assert.match(subjectKey, /^ue:v2:[A-Za-z0-9_-]{43}$/);
      assert.equal(subjectKey.includes(rawPii), false);
      assert.equal(subjectKeyVersion(subjectKey), 2);
      const rotated = createEconomicsSubjectKeysForRotation("user", rawPii);
      assert.equal(rotated.length, 2);
      assert.match(rotated[0], /^ue:v1:/);
      assert.match(rotated[1], /^ue:v2:/);
      assert.notEqual(rotated[0], rotated[1]);
      assert.notEqual(createEconomicsSubjectKey("device", rawPii), subjectKey);
      assert.match(createEconomicsEventKey("route", "stable-call"), /^uee:v2:/);
      assert.match(createEconomicsBreachKey("subject", day), /^ueb:v2:/);
      assert.match(createEconomicsBreachDedupKey("subject", day), /^ued:v2:/);
    });

    await check("production durability assertion", () => {
      (process.env as Record<string, string | undefined>).NODE_ENV = "production";
      process.env.VOICEMEMORY_UNIT_ECONOMICS_ENABLED = "true";
      assert.throws(assertProductionUnitEconomicsIsDurable, /DATABASE_URL/);
      (process.env as Record<string, string | undefined>).NODE_ENV = "test";
      delete process.env.VOICEMEMORY_UNIT_ECONOMICS_ENABLED;
    });

    await check("pricing version selection and immutability", async () => {
      const line = (versionKey: string, price: bigint) => ({
        versionKey,
        metric: "ai_input_tokens" as const,
        resource: "openai.gpt-4o-mini" as const,
        cogsCategory: "ai" as const,
        unitQuantity: 1_000n,
        unitPriceMicroUsd: price,
        costBasis: "exact" as const,
      });
      await insertPricingCatalog({
        versionKey: "prices-v1",
        effectiveFrom: new Date("2026-01-01T00:00:00Z"),
        effectiveTo: new Date("2026-07-01T00:00:00Z"),
        lines: [line("prices-v1", 20n)],
      });
      await insertPricingCatalog({
        versionKey: "prices-v2",
        effectiveFrom: new Date("2026-07-01T00:00:00Z"),
        effectiveTo: null,
        lines: [line("prices-v2", 25n)],
      });
      assert.equal((await selectPricingCatalog(new Date("2026-06-30T23:59:59Z")))?.versionKey, "prices-v1");
      assert.equal((await selectPricingCatalog(occurredAt))?.versionKey, "prices-v2");
      assert.equal(await insertPricingCatalog({
        versionKey: "prices-v2",
        effectiveFrom: new Date("2026-07-01T00:00:00Z"),
        effectiveTo: null,
        lines: [line("prices-v2", 25n)],
      }), false);
      await assert.rejects(() => insertPricingCatalog({
        versionKey: "prices-v2",
        effectiveFrom: new Date("2026-07-01T00:00:00Z"),
        effectiveTo: null,
        lines: [line("prices-v2", 26n)],
      }), /immutable/);
    });

    await check("production pricing catalog coverage and assumptions", async () => {
      const loaded = await loadPricingCatalog();
      assert.equal(loaded.metadata.currency, "USD");
      assert.match(loaded.metadata.source.asOf, /^\d{4}-\d{2}-\d{2}$/);
      assert.ok(loaded.metadata.source.assumption.includes("verify"));
      assert.equal(pricingCoverageErrors(loaded.catalog.lines).length, 0);
      assert.equal(loaded.catalog.lines.length, REQUIRED_PRICING_PAIRS.length);
      assert.ok(loaded.catalog.lines.every((line) =>
        line.unitQuantity > 0n &&
        line.unitPriceMicroUsd >= 0n &&
        line.costBasis === "estimated"));
    });

    await check("readiness rejects missing active pricing", async () => {
      resetUnitEconomicsPricingMemoryForTests();
      process.env.VOICEMEMORY_UNIT_ECONOMICS_ENABLED = "true";
      process.env.VOICEMEMORY_UNIT_ECONOMICS_PRICING_REQUIRED = "true";
      const missing = await getUnitEconomicsReadiness(occurredAt);
      assert.equal(missing.ready, false);
      assert.ok(missing.codes.includes("ACTIVE_PRICING_CATALOG_MISSING"));
      const { catalog } = await loadPricingCatalog();
      await insertPricingCatalog(catalog);
      const ready = await getUnitEconomicsReadiness(occurredAt);
      assert.equal(ready.ready, true);
      assert.equal(ready.activePricingVersion, catalog.versionKey);
      delete process.env.VOICEMEMORY_UNIT_ECONOMICS_ENABLED;
    });

    await check("Postgres pricing inserts are atomic and serialized", async () => {
      const source = await readFile(
        path.join(process.cwd(), "lib/server/unit-economics-pricing-store.ts"),
        "utf8",
      );
      for (const required of [
        "getDatabasePool().connect()",
        "BEGIN",
        "pg_advisory_xact_lock",
        "getPricingCatalogWithClient",
        "COMMIT",
        "ROLLBACK",
        "client.release()",
      ]) {
        assert.ok(source.includes(required), `pricing transaction missing ${required}`);
      }
      const lockIndex = source.indexOf("pg_advisory_xact_lock");
      assert.ok(
        lockIndex < source.indexOf("const existing", lockIndex),
        "pricing lock must precede existing-catalog and overlap checks",
      );
    });

    await check("fixed-point cost arithmetic", () => {
      assert.equal(calculateCostMicroUsd(1_500n, 25n, 1_000n), 38n);
      assert.equal(calculateCostMicroUsd(10n ** 18n, 3_000_000n, 1_000_000n), 3n * 10n ** 18n);
    });

    await check("measurement quality cannot override immutable pricing basis", async () => {
      const engineSource = await readFile(
        path.join(process.cwd(), "lib/server/unit-economics-engine.ts"),
        "utf8",
      );
      const meterSource = await readFile(
        path.join(process.cwd(), "lib/server/unit-economics-meter.ts"),
        "utf8",
      );
      assert.match(engineSource, /line\.costBasis === "exact"/);
      assert.match(engineSource, /measurementBasis: input\.measurementBasis/);
      assert.match(meterSource, /measurementBasis: input\.measurementBasis/);
    });

    await check("actual OpenAI token class extraction", () => {
      assert.deepEqual(extractOpenAiTokenClasses({
        prompt_tokens: 120,
        completion_tokens: 50,
        prompt_tokens_details: { cached_tokens: 20 },
        completion_tokens_details: { reasoning_tokens: 10 },
      }), {
        input: 100,
        output: 40,
        cached: 20,
        reasoning: 10,
        actual: true,
      });
      assert.deepEqual(extractOpenAiTokenClasses(undefined, { input: 7, output: 3 }), {
        input: 7, output: 3, cached: 0, reasoning: 0, actual: false,
      });
      assert.equal(vendorRequestId({ _request_id: "req_vendor_1" }, "client"), "req_vendor_1");
      assert.equal(vendorRequestId({}, "client"), "client");
    });

    await check("exact OpenAI classes are idempotent by vendor request", async () => {
      resetUnitEconomicsLedgerMemoryForTests();
      process.env.VOICEMEMORY_UNIT_ECONOMICS_ENABLED = "true";
      const exactTokenDay = utcDay(new Date());
      const metering = {
        operation: "test.openai-exact",
        subject: { kind: "user" as const, id: rawPii },
        idempotencyKey: "req_vendor_exact_1",
        resource: "openai.gpt-4o-mini" as const,
        modelDimension: "gpt-4o-mini" as const,
        usage: {
          prompt_tokens: 120,
          completion_tokens: 50,
          prompt_tokens_details: { cached_tokens: 20 },
          completion_tokens_details: { reasoning_tokens: 10 },
        },
      };
      await meterOpenAiChatUsage(metering);
      await meterOpenAiChatUsage(metering);
      const rows = await listUsageLedgerRows(subjectKey, exactTokenDay);
      assert.deepEqual(
        rows.map((row) => [row.metric, row.quantity]).sort(),
        [
          ["ai_cached_tokens", 20n],
          ["ai_input_tokens", 100n],
          ["ai_output_tokens", 40n],
          ["ai_reasoning_tokens", 10n],
        ],
      );
      assert.ok(rows.every((row) => row.measurementBasis === "exact"));
      delete process.env.VOICEMEMORY_UNIT_ECONOMICS_ENABLED;
      resetUnitEconomicsLedgerMemoryForTests();
    });

    await check("exact bytes and duration units", () => {
      assert.equal(exactUtf8Bytes("a\u20ac"), 4);
      const serialized = serializeJsonBody({ value: "a\u20ac" });
      assert.equal(serialized.bytes, Buffer.byteLength(serialized.body, "utf8"));
      const response = serializedJsonResponse(serialized);
      assert.equal(response.headers.get("content-type"), "application/json; charset=utf-8");
      assert.deepEqual(transcriptionDurationMilliseconds(1.2345, 9), {
        quantity: 1_235,
        basis: "exact",
      });
      assert.deepEqual(transcriptionDurationMilliseconds(undefined, 2.5), {
        quantity: 2_500,
        basis: "estimated",
      });
    });

    await check("storage snapshots are exact private and idempotent", async () => {
      resetUnitEconomicsLedgerMemoryForTests();
      assert.equal(await recordStorageFootprintRows(day, [{
        rawUserId: rawPii,
        bytes: 321n,
      }]), 1);
      assert.equal(await recordStorageFootprintRows(day, [{
        rawUserId: rawPii,
        bytes: 321n,
      }]), 0);
      const rows = await listUsageLedgerRows(subjectKey, day);
      assert.equal(rows.length, 1);
      assert.equal(rows[0].metric, "storage_snapshot_bytes");
      assert.equal(rows[0].quantity, 321n);
      assert.equal(rows[0].measurementBasis, "exact");
      const encoded = JSON.stringify(rows, (_key, value: unknown) =>
        typeof value === "bigint" ? value.toString() : value);
      assert.equal(encoded.includes(rawPii), false);
      const source = await readFile(
        path.join(process.cwd(), "lib/server/unit-economics-storage-reconcile.ts"),
        "utf8",
      );
      assert.ok(source.includes("pg_column_size(sb)"));
      assert.ok(source.includes("pg_column_size(je)"));
      assert.equal(source.includes("console."), false);
      resetUnitEconomicsLedgerMemoryForTests();
    });

    await check("cron bearer authentication is timing safe and isolated", () => {
      assert.equal(authorizeUnitEconomicsCron("Bearer correct", "correct"), true);
      assert.equal(authorizeUnitEconomicsCron("Bearer wrong", "correct"), false);
      assert.equal(authorizeUnitEconomicsCron(null, "correct"), false);
      assert.equal(authorizeUnitEconomicsCron("Bearer correct", ""), false);
    });

    await check("best-effort metering disabled and idempotent", async () => {
      delete process.env.VOICEMEMORY_UNIT_ECONOMICS_ENABLED;
      assert.equal(await meterBestEffort({
        operation: "test.disabled",
        subject: { kind: "user", id: rawPii },
        idempotencyKey: "opaque-test-call",
        metric: "ai_input_tokens",
        resource: "openai.gpt-4o-mini",
        quantity: 10,
        measurementBasis: "exact",
      }), false);
      process.env.VOICEMEMORY_UNIT_ECONOMICS_ENABLED = "true";
      const input = {
        operation: "test.idempotent",
        subject: { kind: "user" as const, id: rawPii },
        idempotencyKey: "opaque-test-call",
        metric: "ai_input_tokens" as const,
        resource: "openai.gpt-4o-mini" as const,
        quantity: 1_000,
        measurementBasis: "estimated" as const,
        occurredAt,
      };
      assert.equal(await meterBestEffort(input), true);
      assert.equal(await meterBestEffort(input), false);
      const metered = await listUsageLedgerRows(subjectKey, day);
      assert.equal(metered.length, 1);
      assert.equal(metered[0].measurementBasis, "estimated");
      assert.equal(metered[0].exactCostMicroUsd, 0n);
      assert.equal(metered[0].estimatedCostMicroUsd, 150n);
      delete process.env.VOICEMEMORY_UNIT_ECONOMICS_ENABLED;
      resetUnitEconomicsLedgerMemoryForTests();
    });

    await check("best-effort errors exclude identifiers and content", async () => {
      process.env.VOICEMEMORY_UNIT_ECONOMICS_ENABLED = "true";
      const messages: string[] = [];
      const original = console.error;
      console.error = (...values: unknown[]) => { messages.push(values.join(" ")); };
      try {
        assert.equal(await meterBestEffort({
          operation: "test.failure",
          subject: { kind: "user", id: rawPii },
          idempotencyKey: "private-entry-or-blob-id",
          metric: "ai_input_tokens",
          resource: "openai.gpt-4o-mini",
          quantity: -1,
          measurementBasis: "exact",
        }), false);
      } finally {
        console.error = original;
        delete process.env.VOICEMEMORY_UNIT_ECONOMICS_ENABLED;
      }
      assert.equal(messages.length, 1);
      assert.equal(messages[0].includes(rawPii), false);
      assert.equal(messages[0].includes("private-entry-or-blob-id"), false);
      assert.deepEqual(Object.keys(JSON.parse(messages[0]) as object).sort(), [
        "component", "errorCode", "operation", "severity",
      ]);
    });

    await check("money metering is private and idempotent", async () => {
      process.env.VOICEMEMORY_UNIT_ECONOMICS_ENABLED = "true";
      const providerEventId = "evt_raw_provider_revenue_secret";
      const input = {
        operation: "test.stripe-revenue",
        subject: { kind: "user" as const, id: rawPii },
        idempotencyKey: providerEventId,
        metric: "revenue" as const,
        amountMicroUsd: 12_340_000n,
        resource: "stripe.subscription" as const,
        dimensions: { provider: "stripe" as const },
        occurredAt,
      };
      assert.equal(await meterMoneyBestEffort(input), true);
      assert.equal(await meterMoneyBestEffort(input), true);
      const rows = await listUsageLedgerRows(subjectKey, day);
      assert.equal(rows.length, 1);
      assert.equal(rows[0].exactCostMicroUsd, 12_340_000n);
      const serialized = JSON.stringify(
        rows,
        (_key, value: unknown) => typeof value === "bigint" ? value.toString() : value,
      );
      assert.equal(serialized.includes(providerEventId), false);
      assert.equal(serialized.includes(rawPii), false);
      delete process.env.VOICEMEMORY_UNIT_ECONOMICS_ENABLED;
      resetUnitEconomicsLedgerMemoryForTests();
    });

    await check("money metering errors exclude identifiers and amounts", async () => {
      process.env.VOICEMEMORY_UNIT_ECONOMICS_ENABLED = "true";
      const messages: string[] = [];
      const original = console.error;
      console.error = (...values: unknown[]) => { messages.push(values.join(" ")); };
      try {
        assert.equal(await meterMoneyBestEffort({
          operation: "test.money-failure",
          subject: { kind: "user", id: rawPii },
          idempotencyKey: "raw-provider-event",
          metric: "revenue",
          amountMicroUsd: -987_654_321n,
          resource: "stripe.subscription",
        }), false);
      } finally {
        console.error = original;
        delete process.env.VOICEMEMORY_UNIT_ECONOMICS_ENABLED;
      }
      assert.equal(messages.length, 1);
      assert.equal(messages[0].includes(rawPii), false);
      assert.equal(messages[0].includes("raw-provider-event"), false);
      assert.equal(messages[0].includes("987654321"), false);
    });

    await check("finance revenue input accepts pseudonymous subjects only", () => {
      const valid = parseFinanceRevenueInput({
        subjectKey,
        provider: "revenuecat",
        metric: "adjustments",
        amountMicroUsd: "-250000",
        occurredAt: occurredAt.toISOString(),
        externalEventToken: "finance-event-token",
      });
      assert.equal(valid.ok, true);
      assert.equal(parseFinanceRevenueInput({
        subjectKey: rawPii,
        provider: "revenuecat",
        metric: "revenue",
        amountMicroUsd: "100",
        occurredAt: occurredAt.toISOString(),
        externalEventToken: "finance-event-token",
      }).ok, false);
      assert.equal(parseFinanceRevenueInput({
        subjectKey,
        provider: "unknown",
        metric: "revenue",
        amountMicroUsd: "100",
        occurredAt: occurredAt.toISOString(),
        externalEventToken: "finance-event-token",
      }).ok, false);
    });

    const baseRow = (event: string, amount: bigint, category: UsageLedgerRow["category"], metric: UsageLedgerRow["metric"]): UsageLedgerRow => ({
      eventKey: createEconomicsEventKey(event),
      subjectKey,
      subjectKeyVersion: 2,
      metric,
      resource: metric === "revenue"
        ? "stripe.subscription"
        : metric === "credits"
          ? "credit.subscription"
          : metric === "adjustments"
            ? "adjustment.correction"
            : "openai.gpt-4o-mini",
      quantity: metric === "adjustments" ? amount : 1n,
      category,
      exactCostMicroUsd: amount,
      estimatedCostMicroUsd: 0n,
      measurementBasis: "exact",
      pricingVersionKey: null,
      dimensions: { plan: "pro" },
      occurredAt,
      day,
    });

    await check("ledger idempotency and no PII", async () => {
      const row = baseRow("revenue-one", 1_000_000n, "revenue", "revenue");
      assert.equal(await appendUsageLedgerRow(row), true);
      assert.equal(await appendUsageLedgerRow(row), false);
      const stored = await listUsageLedgerRows(subjectKey, day);
      assert.equal(stored.length, 1);
      const serialized = JSON.stringify(
        stored,
        (_key, value: unknown) => typeof value === "bigint" ? value.toString() : value,
      );
      assert.equal(serialized.includes(rawPii), false);
    });

    await check("compensating adjustments and daily rollups", async () => {
      await appendUsageLedgerRow(baseRow("credits-one", 100_000n, "credits", "credits"));
      await appendUsageLedgerRow({
        ...baseRow("ai-cogs", 250_000n, "ai", "ai_input_tokens"),
        resource: "openai.gpt-4o-mini",
        quantity: 1_000n,
        pricingVersionKey: "prices-v2",
      });
      await recordMoneyLedgerRow({
        eventParts: ["correction", "revenue-one", "1"],
        subjectKey,
        metric: "adjustments",
        amountMicroUsd: -50_000n,
        resource: "adjustment.correction",
        occurredAt,
      });
      const rollup = await reconcileDailySubjectRollup(subjectKey, day);
      assert.equal(rollup.revenueMicroUsd, 1_000_000n);
      assert.equal(rollup.creditsMicroUsd, 100_000n);
      assert.equal(rollup.totalCogsMicroUsd, 250_000n);
      assert.equal(rollup.adjustmentsMicroUsd, -50_000n);
      assert.equal(rollup.contributionMarginMicroUsd, 600_000n);
      assert.equal(rollup.marginBps, 6_666);
    });

    await check("margin basis points without floats", () => {
      const rollup = calculateDailyRollup(subjectKey, day, [
        baseRow("margin-revenue", 3n, "revenue", "revenue"),
        { ...baseRow("margin-cogs", 1n, "ai", "ai_input_tokens"), resource: "openai.gpt-4o-mini" },
      ]);
      assert.equal(rollup.marginBps, 6_666);
    });

    await check("breach deduplication", async () => {
      const rollup = calculateDailyRollup(subjectKey, day, [
        baseRow("breach-revenue", 100n, "revenue", "revenue"),
        { ...baseRow("breach-cogs", 150n, "ai", "ai_input_tokens"), resource: "openai.gpt-4o-mini" },
      ]);
      const candidates = breachesForRollup(rollup, {
        minimumMarginBps: 2_000n,
        maximumDailyCogsMicroUsd: 1_000n,
        maximumAbsoluteLossMicroUsd: 25n,
      });
      assert.ok(candidates.some((item) => item.thresholdCode === "negative_margin"));
      assert.ok(candidates.some((item) => item.thresholdCode === "absolute_loss"));
      assert.equal(await recordRollupBreaches(rollup, {
        minimumMarginBps: 2_000n,
        maximumDailyCogsMicroUsd: 1_000n,
        maximumAbsoluteLossMicroUsd: 25n,
      }), candidates.length);
      assert.equal(await recordRollupBreaches(rollup, {
        minimumMarginBps: 2_000n,
        maximumDailyCogsMicroUsd: 1_000n,
        maximumAbsoluteLossMicroUsd: 25n,
      }), 0);
      assert.equal(await appendThresholdBreach(candidates[0]), false);
    });

    await check("migration manifest and schema privacy", async () => {
      for (const table of [
        "ue_pricing_versions", "ue_price_lines", "ue_usage_ledger",
        "ue_daily_subject_rollups", "ue_threshold_breaches",
      ]) assert.ok(REQUIRED_TABLES.includes(table as never));
      const embedded = DATABASE_SCHEMA_STATEMENTS.join("\n");
      const migration = await readFile(
        path.join(process.cwd(), "docs/sql/004_unit_economics.sql"),
        "utf8",
      );
      for (const required of [
        "ue_dimensions_are_safe", "ue_usage_ledger_immutable",
        "ue_pricing_versions_immutable", "ue_threshold_breaches_immutable",
        "subject_key", "subject_key_version", "measurement_basis",
        "ue_usage_ledger_day_subject_idx",
      ]) {
        assert.ok(embedded.includes(required), `embedded schema missing ${required}`);
        assert.ok(migration.includes(required), `migration missing ${required}`);
      }
      for (const banned of [
        "user_id", "device_id", "email", "ip_address", "session_id",
        "entry_id", "blob_id", "transcript", "quote", "prompt",
      ]) {
        assert.equal(
          new RegExp(`\\b${banned}\\b`).test(migration),
          false,
          `migration includes raw identity column ${banned}`,
        );
      }
      assert.ok(REQUIRED_INDEXES.some(
        (value) => value.index === "ue_usage_ledger_day_subject_idx",
      ));
      const migrationCli = await readFile(
        path.join(process.cwd(), "scripts/activate-unit-economics-schema.mjs"),
        "utf8",
      );
      for (const required of [
        'client.query("BEGIN")', "client.query(sql)", 'client.query("COMMIT")',
        'client.query("ROLLBACK")', "ue_reject_source_mutation",
        "ue_usage_ledger_day_subject_idx",
      ]) assert.ok(migrationCli.includes(required));
    });

    await check("response metering uses one exact serialization", async () => {
      for (const relative of [
        "app/api/journal/route.ts",
        "app/api/journal/export/route.ts",
        "app/api/sync/pull/route.ts",
      ]) {
        const source = await readFile(path.join(process.cwd(), relative), "utf8");
        assert.ok(source.includes("serializeJsonBody"));
        assert.ok(source.includes("serializedJsonResponse(serialized)"));
        assert.ok(source.includes("quantity: serialized.bytes"));
      }
      const syncPush = await readFile(
        path.join(process.cwd(), "app/api/sync/push/route.ts"),
        "utf8",
      );
      const vaultChunk = await readFile(
        path.join(process.cwd(), "experiments/backend/app/api/live-audio/vault-chunk/route.ts"),
        "utf8",
      );
      assert.equal(syncPush.includes('metric: "storage_snapshot_bytes"'), false);
      assert.equal(vaultChunk.includes('metric: "storage_snapshot_bytes"'), false);
    });

    await check("internal route authorization and serialization contracts", async () => {
      for (const relative of [
        "app/api/internal/unit-economics/reconcile/route.ts",
        "app/api/internal/unit-economics/report/route.ts",
        "app/api/internal/unit-economics/pricing/route.ts",
        "app/api/internal/unit-economics/revenue/route.ts",
      ]) {
        const source = await readFile(path.join(process.cwd(), relative), "utf8");
        assert.ok(source.includes('runtime = "nodejs"'));
        assert.ok(source.includes('dynamic = "force-dynamic"'));
        assert.ok(source.includes("authorizeInternalPushApi"));
      }
      const report = await readFile(
        path.join(process.cwd(), "app/api/internal/unit-economics/report/route.ts"),
        "utf8",
      );
      assert.ok(report.includes(".toString()"));
      assert.equal(report.includes("eventKey"), false);
      const reconcile = await readFile(
        path.join(process.cwd(), "app/api/internal/unit-economics/reconcile/route.ts"),
        "utf8",
      );
      assert.ok(reconcile.includes("export async function GET"));
      assert.ok(reconcile.includes("authorizeUnitEconomicsCron"));
      assert.ok(
        reconcile.indexOf("storageSnapshotsInserted += await reconcileDailyStorageSnapshots") <
          reconcile.indexOf("const pairs = await listUsageSubjectDays"),
      );
    });
  } finally {
    for (const name of envNames) {
      const value = saved[name];
      if (value === undefined) delete process.env[name];
      else (process.env as Record<string, string | undefined>)[name] = value;
    }
  }
  return { failures };
}
