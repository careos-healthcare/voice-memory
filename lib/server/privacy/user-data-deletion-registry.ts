import "server-only";

import fs from "node:fs/promises";

export const USER_DATA_DELETION_REGISTRY_VERSION = 4;

export type DeletionQuery = <Row extends Record<string, unknown> = Record<string, unknown>>(
  text: string,
  params?: unknown[],
) => Promise<{ rowCount: number | null; rows: Row[] }>;

export interface UserDeletionContext {
  userId: string;
  normalizedEmail: string;
  subjectKey: string;
  economicsSubjectKeys: readonly string[];
  syncDirectory: string | null;
  storageMode: "postgres" | "local";
  query: DeletionQuery;
  deleteLocal(resourceId: string): Promise<number>;
  verifyLocal(resourceId: string): Promise<boolean>;
}

export interface DeletionResource {
  id: string;
  resourceType: "database-table" | "filesystem";
  dataClassification: "authentication" | "profile" | "encrypted-content" | "content" | "behavioral" | "billing" | "identifier" | "operational";
  lookupStrategy: string;
  deletionStrategy: string;
  requiredness: "required" | "optional";
  userLink: "user_id" | "email" | "subject_key" | "hmac_subject_key";
  tables: readonly string[];
  order: number;
  dependsOn: readonly string[];
  retryPolicy: { maxAttempts: number | "unbounded"; backoff: "none" | "exponential" };
  idempotency: "delete-missing-is-success";
  retentionRuleId: "PRIVACY-ACCOUNT-DELETE-IMMEDIATE";
  handler(context: UserDeletionContext): Promise<number>;
  verifier(context: UserDeletionContext): Promise<boolean>;
}

function postgresResource(input: {
  id: string;
  dataClassification: DeletionResource["dataClassification"];
  userLink: DeletionResource["userLink"];
  tables: readonly string[];
  order: number;
  dependsOn?: readonly string[];
  deleteSql: string;
  verifySql: string;
  params: (context: UserDeletionContext) => unknown[];
}): DeletionResource {
  return {
    id: input.id,
    resourceType: "database-table",
    dataClassification: input.dataClassification,
    lookupStrategy: `${input.userLink}:parameterized`,
    deletionStrategy: "hard-delete",
    requiredness: "required",
    userLink: input.userLink,
    tables: input.tables,
    order: input.order,
    dependsOn: input.dependsOn ?? (input.order === 0 ? [] : ["sessions"]),
    retryPolicy: { maxAttempts: "unbounded", backoff: "exponential" },
    idempotency: "delete-missing-is-success",
    retentionRuleId: "PRIVACY-ACCOUNT-DELETE-IMMEDIATE",
    async handler(context) {
      if (context.storageMode === "local") return context.deleteLocal(input.id);
      const result = await context.query(input.deleteSql, input.params(context));
      return result.rowCount ?? 0;
    },
    async verifier(context) {
      if (context.storageMode === "local") return context.verifyLocal(input.id);
      const result = await context.query<{ remaining: string | number }>(
        input.verifySql,
        input.params(context),
      );
      return Number(result.rows[0]?.remaining ?? 0) === 0;
    },
  };
}

const byUserId = (
  id: string,
  table: string,
  dataClassification: DeletionResource["dataClassification"],
  order: number,
): DeletionResource =>
  postgresResource({
    id,
    dataClassification,
    userLink: "user_id",
    tables: [table],
    order,
    deleteSql: `DELETE FROM ${table} WHERE user_id = $1`,
    verifySql: `SELECT count(*) AS remaining FROM ${table} WHERE user_id = $1`,
    params: (context) => [context.userId],
  });

const bySubjectKey = (
  id: string,
  table: string,
  order: number,
): DeletionResource =>
  postgresResource({
    id,
    dataClassification: "operational",
    userLink: "subject_key",
    tables: [table],
    order,
    deleteSql: `DELETE FROM ${table} WHERE subject_key = $1`,
    verifySql: `SELECT count(*) AS remaining FROM ${table} WHERE subject_key = $1`,
    params: (context) => [context.subjectKey],
  });

/**
 * The single executable registry for server-side data linked to an account.
 * SQL identifiers are static; only values are parameterized.
 */
export const USER_DATA_DELETION_REGISTRY: readonly DeletionResource[] = [
  byUserId("sessions", "sessions", "authentication", 0),
  postgresResource({
    id: "auth-codes",
    dataClassification: "authentication",
    userLink: "email",
    tables: ["auth_codes"],
    order: 10,
    deleteSql: "DELETE FROM auth_codes WHERE email = $1",
    verifySql: "SELECT count(*) AS remaining FROM auth_codes WHERE email = $1",
    params: (context) => [context.normalizedEmail],
  }),
  byUserId("profiles", "user_profiles", "profile", 20),
  byUserId("sync-blobs", "sync_blobs", "encrypted-content", 30),
  bySubjectKey("api-usage", "api_usage", 40),
  bySubjectKey("api-minute-usage", "api_minute_usage", 41),
  bySubjectKey("openai-daily-spend", "openai_daily_spend", 42),
  byUserId("journal-entries", "journal_entries", "content", 50),
  postgresResource({
    id: "resurfacing-events",
    dataClassification: "behavioral",
    userLink: "user_id",
    tables: ["resurfacing_events"],
    order: 60,
    deleteSql: "DELETE FROM resurfacing_events WHERE user_id = $1 OR subject_key = $2",
    verifySql:
      "SELECT count(*) AS remaining FROM resurfacing_events WHERE user_id = $1 OR subject_key = $2",
    params: (context) => [context.userId, context.subjectKey],
  }),
  byUserId("resurfacing-feedback", "resurfacing_feedback", "behavioral", 61),
  byUserId("ai-accuracy-feedback-and-corrections", "ai_accuracy_feedback", "content", 62),
  byUserId("mobile-push-devices-and-fcm-tokens", "mobile_push_devices", "identifier", 70),
  byUserId("billing-entitlements", "billing_entitlements", "billing", 80),
  byUserId("revenuecat-user-mappings", "revenuecat_user_mappings", "identifier", 81),
  byUserId("billing-entitlement-sources", "billing_entitlement_sources", "billing", 82),
  byUserId("usage-reservations", "usage_reservations", "operational", 83),
  postgresResource({
    id: "unit-economics-rotated-hmac-subjects",
    dataClassification: "operational",
    userLink: "hmac_subject_key",
    tables: ["ue_usage_ledger", "ue_daily_subject_rollups", "ue_threshold_breaches"],
    order: 90,
    deleteSql: "SELECT delete_user_unit_economics($1::text[])",
    verifySql: `SELECT (
      (SELECT count(*) FROM ue_usage_ledger WHERE subject_key = ANY($1::text[])) +
      (SELECT count(*) FROM ue_daily_subject_rollups WHERE subject_key = ANY($1::text[])) +
      (SELECT count(*) FROM ue_threshold_breaches WHERE subject_key = ANY($1::text[]))
    ) AS remaining`,
    params: (context) => [context.economicsSubjectKeys],
  }),
  {
    id: "filesystem-sync-blobs",
    resourceType: "filesystem",
    dataClassification: "encrypted-content",
    lookupStrategy: "user_id:path-segment",
    deletionStrategy: "recursive-hard-delete",
    requiredness: "required",
    userLink: "user_id",
    tables: [],
    order: 31,
    dependsOn: ["sessions"],
    retryPolicy: { maxAttempts: "unbounded", backoff: "exponential" },
    idempotency: "delete-missing-is-success",
    retentionRuleId: "PRIVACY-ACCOUNT-DELETE-IMMEDIATE",
    async handler(context) {
      if (!context.syncDirectory) return 0;
      try {
        await fs.rm(context.syncDirectory, { recursive: true, force: true });
        return 1;
      } catch (error) {
        if ((error as NodeJS.ErrnoException).code === "ENOENT") return 0;
        throw error;
      }
    },
    async verifier(context) {
      if (!context.syncDirectory) return true;
      try {
        await fs.access(context.syncDirectory);
        return false;
      } catch (error) {
        if ((error as NodeJS.ErrnoException).code === "ENOENT") return true;
        throw error;
      }
    },
  },
] as const;

export interface ExternalDeletionContext {
  externalId: string | null;
  run(processorId: string, externalId: string): Promise<"complete" | "blocked" | "retry">;
  status(processorId: string): Promise<"missing" | "pending" | "complete" | "blocked">;
}

function externalProcessor(input: {
  id: string;
  mappingTable: string | null;
  requiredWhenMapped: boolean;
  behavior: string;
}) {
  return {
    ...input,
    resourceType: "external-processor" as const,
    dataClassification: "processor-data" as const,
    lookupStrategy: input.mappingTable ? "captured-mapping-outbox" : "no-durable-mapping",
    deletionStrategy: input.requiredWhenMapped ? "provider-api-hard-delete" : "local-mapping-only",
    requiredness: input.requiredWhenMapped ? "required-when-mapped" as const : "optional" as const,
    order: 100,
    dependsOn: input.mappingTable ? [input.mappingTable] : [],
    retryPolicy: { maxAttempts: "unbounded" as const, backoff: "exponential" as const },
    idempotency: "provider-delete-or-not-found-is-success" as const,
    retentionRuleId: "PRIVACY-ACCOUNT-DELETE-IMMEDIATE" as const,
    async handler(context: ExternalDeletionContext) {
      if (!context.externalId) return "complete" as const;
      return context.run(input.id, context.externalId);
    },
    async verifier(context: ExternalDeletionContext) {
      const status = await context.status(input.id);
      return status === "missing" || status === "complete";
    },
  };
}

export const EXTERNAL_DELETION_PROCESSORS = [
  externalProcessor({
    id: "stripe-customer",
    mappingTable: "billing_entitlements",
    requiredWhenMapped: true,
    behavior: "Delete the mapped Stripe customer; Stripe performs subscription cancellation.",
  }),
  externalProcessor({
    id: "revenuecat-subscriber",
    mappingTable: "revenuecat_user_mappings",
    requiredWhenMapped: true,
    behavior: "Delete the mapped RevenueCat subscriber through its REST API.",
  }),
  externalProcessor({
    id: "firebase-cloud-messaging",
    mappingTable: "mobile_push_devices",
    requiredWhenMapped: false,
    behavior:
      "Delete local FCM registration tokens. Firebase exposes no server-side user record keyed by this account.",
  }),
  externalProcessor({
    id: "openai-api",
    mappingTable: null,
    requiredWhenMapped: false,
    behavior:
      "No durable provider object or provider user identifier is created by this service.",
  }),
] as const;

export const REGISTERED_USER_LINKED_TABLES = [
  ...new Set(USER_DATA_DELETION_REGISTRY.flatMap((resource) => resource.tables)),
] as const;
