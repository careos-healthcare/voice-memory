import { mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

import { getStripeBillingConfig, isStripeConfigured } from "@/lib/billing/stripe-config";
import {
  REQUIRED_STRIPE_WEBHOOK_EVENTS,
  stripeIntegrationAudit,
} from "@/lib/billing/stripe-integration-audit";

export type StripeLiveCheckStatus = "pass" | "fail" | "skip" | "manual";

export interface StripeLiveCheckItem {
  name: string;
  status: StripeLiveCheckStatus;
  detail: string;
}

export interface StripeLiveReport {
  at: string;
  envConfigured: boolean;
  codeIntegrationOk: boolean;
  priceLookupOk: boolean | null;
  webhookProof: "proven" | "MANUAL_PROOF_REQUIRED";
  liveStripeEnvReady: boolean;
  exitCode: number;
  checks: StripeLiveCheckItem[];
}

function envPresent(name: string): boolean {
  return Boolean(process.env[name]?.trim());
}

function keyPrefix(name: string): string | null {
  const v = process.env[name]?.trim();
  if (!v) return null;
  if (v.startsWith("sk_live_")) return "sk_live_";
  if (v.startsWith("sk_test_")) return "sk_test_";
  if (v.startsWith("whsec_")) return "whsec_";
  if (v.startsWith("price_")) return "price_";
  return "present";
}

export async function runStripeLiveCheck(options?: {
  retrievePrice?: boolean;
}): Promise<StripeLiveReport> {
  const checks: StripeLiveCheckItem[] = [];
  const add = (name: string, status: StripeLiveCheckStatus, detail: string) => {
    checks.push({ name, status, detail });
  };

  const config = getStripeBillingConfig();
  const envConfigured = config.enabled;

  for (const key of [
    "STRIPE_SECRET_KEY",
    "STRIPE_WEBHOOK_SECRET",
    "STRIPE_PRO_PRICE_ID",
    "NEXT_PUBLIC_APP_URL",
  ]) {
    const prefix = keyPrefix(key);
    if (prefix) {
      add(key, "pass", `Present (${prefix} — value not logged).`);
    } else {
      add(key, "fail", "Missing.");
    }
  }

  const audit = stripeIntegrationAudit();
  for (const item of audit) {
    add(item.name, item.ok ? "pass" : "fail", item.detail);
  }

  const priceOnlyServer = assertPriceIdServerOnly();
  add(
    "STRIPE_PRO_PRICE_ID server-only",
    priceOnlyServer.ok ? "pass" : "fail",
    priceOnlyServer.detail,
  );

  let priceLookupOk: boolean | null = null;
  if (options?.retrievePrice && config.enabled && config.secretKey && config.priceId) {
    try {
      const { default: Stripe } = await import("stripe");
      const client = new Stripe(config.secretKey);
      const price = await client.prices.retrieve(config.priceId);
      priceLookupOk = price.active === true;
      add(
        "STRIPE_PRO_PRICE_ID lookup",
        priceLookupOk ? "pass" : "fail",
        priceLookupOk
          ? `Active price (${price.type}, recurring=${Boolean(price.recurring)}).`
          : "Price exists but is not active.",
      );
    } catch (error) {
      priceLookupOk = false;
      add(
        "STRIPE_PRO_PRICE_ID lookup",
        "fail",
        error instanceof Error ? error.message : "Price lookup failed",
      );
    }
  } else if (!config.enabled) {
    add("STRIPE_PRO_PRICE_ID lookup", "skip", "Stripe env incomplete — skip API lookup.");
  } else {
    add(
      "STRIPE_PRO_PRICE_ID lookup",
      "skip",
      "Pass --retrieve-price to verify price against Stripe API.",
    );
  }

  const webhookProof =
    process.env.STRIPE_WEBHOOK_LIVE_PROOF === "1" ? "proven" : "MANUAL_PROOF_REQUIRED";

  add(
    "Webhook end-to-end proof",
    webhookProof === "proven" ? "pass" : "manual",
    webhookProof === "proven"
      ? "STRIPE_WEBHOOK_LIVE_PROOF=1 set after manual checklist."
      : "Run Stripe CLI or dashboard test — then set STRIPE_WEBHOOK_LIVE_PROOF=1.",
  );

  add(
    "Required webhook event types (docs)",
    "pass",
    REQUIRED_STRIPE_WEBHOOK_EVENTS.join(", "),
  );

  const codeIntegrationOk = audit.every((a) => a.ok);
  const failed = checks.some((c) => c.status === "fail");
  const liveStripeEnvReady = envConfigured && !failed;

  let exitCode = 0;
  if (!envConfigured || failed) exitCode = 2;
  else if (webhookProof !== "proven") exitCode = 0;

  return {
    at: new Date().toISOString(),
    envConfigured,
    codeIntegrationOk,
    priceLookupOk,
    webhookProof,
    liveStripeEnvReady,
    exitCode,
    checks,
  };
}

export function formatStripeLiveReport(report: StripeLiveReport): string {
  const lines = [
    "# Stripe Live Integration Report",
    "",
    `**Generated:** ${report.at}`,
    "",
    "| Field | Value |",
    "|-------|-------|",
    `| Env configured | ${report.envConfigured} |`,
    `| Code integration | ${report.codeIntegrationOk ? "PASS" : "FAIL"} |`,
    `| Price lookup | ${report.priceLookupOk === null ? "skipped" : report.priceLookupOk} |`,
    `| Webhook proof | ${report.webhookProof} |`,
    `| Live Stripe env ready | ${report.liveStripeEnvReady} |`,
    "",
    "## Checks",
    "",
    ...report.checks.map(
      (c) => `- **${c.status.toUpperCase()}** ${c.name}: ${c.detail}`,
    ),
    "",
    "> Secrets are never printed. Webhook delivery must be proven manually (Stripe CLI or staging).",
    "",
  ];
  return lines.join("\n");
}

export function writeStripeLiveReport(
  report: StripeLiveReport,
  reportPath = resolve(
    process.env.HOME ?? "/Users/chiragpatel",
    "Desktop/spp20/stripe_live_integration_report.md",
  ),
): void {
  const inRepo = resolve(process.cwd(), "docs/reports/stripe_live_integration_report.md");
  const content = formatStripeLiveReport(report);
  for (const target of [reportPath, inRepo]) {
    try {
      mkdirSync(dirname(target), { recursive: true });
      writeFileSync(target, content);
    } catch {
      /* optional external path */
    }
  }
}

/** Ensure price id is not exposed to browser bundles. */
export function assertPriceIdServerOnly(root = process.cwd()): { ok: boolean; detail: string } {
  const banned = [/NEXT_PUBLIC_STRIPE_PRO_PRICE_ID/, /process\.env\.STRIPE_PRO_PRICE_ID/];
  const stack = [
    resolve(root, "app"),
    resolve(root, "components"),
    resolve(root, "lib/billing/stripe-config.ts"),
  ];
  const skipPath = (p: string) =>
    p.includes("/api/billing/") || p.endsWith("stripe-config.ts");

  while (stack.length) {
    const current = stack.pop()!;
    let entries;
    try {
      entries = readdirSync(current, { withFileTypes: true });
    } catch {
      continue;
    }
    for (const ent of entries) {
      const p = resolve(current, ent.name);
      if (ent.isDirectory()) {
        if (!["node_modules", ".next"].includes(ent.name)) stack.push(p);
      } else if (/\.(tsx?|jsx?)$/.test(ent.name) && !skipPath(p)) {
        const text = readFileSync(p, "utf8");
        if (banned.some((re) => re.test(text))) {
          return { ok: false, detail: `Price id env referenced in client path: ${p}` };
        }
      }
    }
  }
  return { ok: true, detail: "STRIPE_PRO_PRICE_ID only used server-side." };
}
