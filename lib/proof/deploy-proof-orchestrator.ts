import { isEmailDisabled } from "@/lib/server/email-mode";
import { validateProductionEnv } from "@/lib/server/production-env";
import { isAuthSecretStrong, isDebugTokenStrong } from "@/lib/server/production-env";
import { usesDurableRateLimits } from "@/lib/server/api-usage-store";
import { hasDatabaseUrl } from "@/lib/server/db";
import { runDatabaseLiveCheck, formatDatabaseLiveReport } from "@/lib/proof/database-live-check";
import { runEmailLiveCheck, writeEmailLiveReport } from "@/lib/proof/email-live-check";
import {
  runStripeWebhookProofCheck,
  writeStripeWebhookLiveReport,
} from "@/lib/proof/stripe-webhook-proof-check";
import type { ProofCheck, ProofReport, ProofVerdict } from "@/lib/proof/proof-result";
import { formatProofChecks } from "@/lib/proof/proof-result";
import {
  validateBillingProofStatusFile,
  validateEmailProofStatusFile,
  validateStagingProofStatusFile,
} from "@/lib/proof/signoff-validation";

export interface DeployProofOrchestratorReport {
  verdict: ProofVerdict;
  label: string;
  sections: Array<{ name: string; report: ProofReport }>;
  allChecks: ProofCheck[];
}

export async function runDeployProofOrchestrator(): Promise<DeployProofOrchestratorReport> {
  const sections: Array<{ name: string; report: ProofReport }> = [];

  const db = await runDatabaseLiveCheck();
  sections.push({ name: "database-live", report: db });
  formatDatabaseLiveReport(db);

  const stripe = await runStripeWebhookProofCheck();
  sections.push({ name: "stripe-webhook-proof", report: stripe });
  writeStripeWebhookLiveReport(stripe);

  const email = await runEmailLiveCheck();
  sections.push({ name: "email-live", report: email });
  writeEmailLiveReport(email);

  const extra: ProofCheck[] = [];
  const prod = validateProductionEnv({ strict: true });
  extra.push({
    name: "production-env-strict",
    status: prod.ok ? "pass" : "blocked",
    detail: prod.ok
      ? "Strict production env OK."
      : `Deploy host env incomplete: ${prod.issues.map((i) => i.code).join(", ")}`,
  });

  const authSecret = process.env.AUTH_SECRET?.trim();
  extra.push({
    name: "AUTH_SECRET",
    status: !authSecret
      ? "blocked"
      : isAuthSecretStrong(process.env.AUTH_SECRET)
        ? "pass"
        : "fail",
    detail: !authSecret
      ? "Set AUTH_SECRET on deploy host."
      : isAuthSecretStrong(process.env.AUTH_SECRET)
        ? "Strong AUTH_SECRET."
        : "Weak AUTH_SECRET — rotate before launch.",
  });

  const debug = process.env.DEBUG_ACCESS_TOKEN?.trim();
  extra.push({
    name: "DEBUG_ACCESS_TOKEN",
    status: !debug || isDebugTokenStrong(debug) ? "pass" : "fail",
    detail: !debug
      ? "Unset (recommended)."
      : isDebugTokenStrong(debug)
        ? "Strong token (not logged)."
        : "Weak DEBUG_ACCESS_TOKEN.",
  });

  const appUrl =
    process.env.NEXT_PUBLIC_APP_URL?.trim() || process.env.APP_URL?.trim() || "";
  extra.push({
    name: "HTTPS_APP_URL",
    status:
      appUrl && (process.env.NODE_ENV !== "production" || appUrl.startsWith("https://"))
        ? "pass"
        : appUrl
          ? "fail"
          : "blocked",
    detail: appUrl
      ? process.env.NODE_ENV === "production" && !appUrl.startsWith("https://")
        ? "Production requires HTTPS app URL."
        : "App URL configured (host not logged)."
      : "NEXT_PUBLIC_APP_URL or APP_URL missing.",
  });

  extra.push({
    name: "RATE_LIMITER_DURABLE",
    status: !hasDatabaseUrl()
      ? "blocked"
      : usesDurableRateLimits()
        ? "pass"
        : "fail",
    detail: !hasDatabaseUrl()
      ? "DATABASE_URL required for durable rate limits."
      : usesDurableRateLimits()
        ? "Postgres-backed rate limits."
        : "Memory-only — not deploy-ready.",
  });

  const signoffs = [
    ...validateStagingProofStatusFile(),
    ...validateBillingProofStatusFile(),
    ...(isEmailDisabled() ? [] : validateEmailProofStatusFile()),
  ];
  extra.push(...signoffs);

  const allChecks = [...sections.flatMap((s) => s.report.checks), ...extra];

  let verdict: ProofVerdict = "PASS";
  if (allChecks.some((c) => c.status === "fail")) verdict = "FAIL";
  else if (allChecks.some((c) => c.status === "blocked")) verdict = "DEPLOY_BLOCKED";

  const label =
    verdict === "PASS"
      ? "PASS"
      : verdict === "FAIL"
        ? "FAIL"
        : "DEPLOY_BLOCKED";

  return { verdict, label, sections, allChecks };
}

export function printDeployProofSummary(report: DeployProofOrchestratorReport): void {
  console.log(`\n=== validate:deploy-secrets — ${report.label} ===\n`);
  for (const section of report.sections) {
    console.log(`— ${section.name} (${section.report.label}) —`);
    formatProofChecks(section.report.checks);
  }
  const sectionCount = report.sections.flatMap((s) => s.report.checks).length;
  console.log("— production gates + sign-offs —");
  formatProofChecks(report.allChecks.slice(sectionCount));
}
