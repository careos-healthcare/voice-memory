import { randomUUID } from "node:crypto";

import type { ProofCheck, ProofReport } from "@/lib/proof/proof-result";
import { summarizeVerdict } from "@/lib/proof/proof-result";
import { checkAndRecordApiUsage } from "@/lib/server/api-usage-store";
import {
  dbQuery,
  getDatabaseDiagnostics,
  hasDatabaseUrl,
  isProductionRuntime,
  shouldUsePostgresStorage,
} from "@/lib/server/db";
import {
  deleteServerJournalEntry,
  listServerJournalEntries,
  upsertServerJournalEntries,
} from "@/lib/server/journal-store";
import { verifyMigrations } from "@/lib/server/migration-verify";
import { REQUIRED_TABLES } from "@/lib/server/migration-manifest";
import type { JournalEntry } from "@/types/journal";

const SYNTHETIC_USER_PREFIX = "proof-synthetic-user";

function sslExpectationDetail(): string {
  const url = process.env.DATABASE_URL?.trim().toLowerCase() ?? "";
  if (!url) return "No DATABASE_URL.";
  if (url.includes("sslmode=disable") || url.includes("ssl=false")) {
    return isProductionRuntime()
      ? "Production URL disables SSL — not recommended."
      : "SSL explicitly disabled in connection string.";
  }
  if (
    url.includes("sslmode=require") ||
    url.includes("neon.tech") ||
    url.includes("supabase") ||
    isProductionRuntime()
  ) {
    return "SSL expected for this host (rejectUnauthorized relaxed for managed providers).";
  }
  return "SSL not required by URL pattern (local/dev).";
}

export async function runDatabaseLiveCheck(): Promise<ProofReport> {
  const checks: ProofCheck[] = [];
  const add = (name: string, status: ProofCheck["status"], detail: string) => {
    checks.push({ name, status, detail });
  };

  if (!hasDatabaseUrl()) {
    add("DATABASE_URL", "blocked", "Required — set on deploy host (value never logged).");
    return {
      verdict: "DEPLOY_BLOCKED",
      label: "DEPLOY_BLOCKED",
      checks,
    };
  }

  add("DATABASE_URL", "pass", "Present (value not logged).");
  add("SSL_POLICY", "pass", sslExpectationDetail());

  try {
    await dbQuery("SELECT 1");
    add("DB_CONNECT", "pass", "Connection OK.");
  } catch (error) {
    add(
      "DB_CONNECT",
      "fail",
      error instanceof Error ? error.message : "Connection failed",
    );
    return { verdict: "FAIL", label: "FAIL", checks };
  }

  const diag = getDatabaseDiagnostics();
  if (diag.lastConnectionError) {
    add("DB_POOL", "fail", `Pool error: ${diag.lastConnectionError}`);
  } else {
    add("DB_POOL", "pass", "Pool initialized without connection errors.");
  }

  if (!shouldUsePostgresStorage()) {
    add("POSTGRES_STORAGE", "fail", "DATABASE_URL set but Postgres storage not active.");
    return { verdict: "FAIL", label: "FAIL", checks };
  }

  const migrations = await verifyMigrations();
  if (migrations.skipped) {
    add("MIGRATIONS", "blocked", migrations.errors.join("; "));
  } else if (!migrations.ok) {
    add(
      "MIGRATIONS",
      "fail",
      `Missing tables: ${migrations.missingTables.join(", ") || "none"}; indexes: ${migrations.missingIndexes.join(", ") || "none"}`,
    );
  } else {
    add("MIGRATIONS", "pass", "Required tables and indexes present.");
  }

  if (REQUIRED_TABLES.includes("resurfacing_feedback")) {
    add("RESURFACING_FEEDBACK_TABLE", "pass", "resurfacing_feedback in migration manifest.");
  }

  const rateSubject = `proof:rate:${randomUUID().slice(0, 12)}`;
  try {
    const first = await checkAndRecordApiUsage(rateSubject, "attest");
    const second = await checkAndRecordApiUsage(rateSubject, "attest");
    if (first.allowed && second.allowed) {
      add("RATE_LIMITER_RW", "pass", "Durable rate limiter write/read OK (synthetic subject).");
    } else {
      add("RATE_LIMITER_RW", "fail", "Unexpected rate limit denial on proof subject.");
    }
    await dbQuery(
      `DELETE FROM api_minute_usage WHERE subject_key = $1`,
      [rateSubject],
    );
    await dbQuery(`DELETE FROM api_usage WHERE subject_key = $1`, [rateSubject]);
  } catch (error) {
    add(
      "RATE_LIMITER_RW",
      "fail",
      error instanceof Error ? error.message : "Rate limiter proof failed",
    );
  }

  const userId = `${SYNTHETIC_USER_PREFIX}-${randomUUID().slice(0, 8)}`;
  const entryId = `proof-entry-${randomUUID().slice(0, 8)}`;
  const entry: JournalEntry = {
    id: entryId,
    createdAt: new Date().toISOString(),
    transcript: "proof synthetic entry — safe to delete",
    durationSeconds: 1,
    reflection: {
      mood: "neutral",
      emotionalIntensity: 1,
      recurringThemes: [],
      hiddenConcern: "",
      positiveSignal: "",
      recommendation: "",
      exactLanguagePattern: "",
      concreteObservation: "proof",
      repeatedSignal: "",
    },
  };

  try {
    await upsertServerJournalEntries(userId, [{ entry }]);
    const rows = await listServerJournalEntries(userId);
    const found = rows.some((r) => r.entryId === entryId);
    await deleteServerJournalEntry(userId, entryId);
    const after = await listServerJournalEntries(userId);
    if (found && after.length === 0) {
      add("JOURNAL_RW", "pass", "Synthetic journal write/read/delete OK.");
    } else {
      add("JOURNAL_RW", "fail", "Journal proof entry lifecycle failed.");
    }
  } catch (error) {
    add(
      "JOURNAL_RW",
      "fail",
      error instanceof Error ? error.message : "Journal proof failed",
    );
  }

  const verdict = summarizeVerdict(checks);
  return {
    verdict: verdict === "DEPLOY_BLOCKED" ? "DEPLOY_BLOCKED" : verdict,
    label: verdict,
    checks,
  };
}

export function formatDatabaseLiveReport(report: ProofReport): string {
  return [
    "# Database live proof report",
    "",
    `**At:** ${new Date().toISOString()}`,
    `**Verdict:** ${report.label}`,
    "",
    "| Check | Status | Detail |",
    "|-------|--------|--------|",
    ...report.checks.map((c) => `| ${c.name} | ${c.status} | ${c.detail} |`),
    "",
    "> DATABASE_URL and connection strings are never printed.",
    "",
  ].join("\n");
}
