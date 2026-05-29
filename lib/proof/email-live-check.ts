import { writeFileSync } from "node:fs";

import type { ProofCheck, ProofReport } from "@/lib/proof/proof-result";
import { summarizeVerdict } from "@/lib/proof/proof-result";
import {
  EMAIL_STATUS_PATH,
  isFreshIsoDate,
  readJsonFile,
  requireTruthy,
  SPP20_DIR,
} from "@/lib/proof/signoff-files";
import { getEmailMode, isEmailDisabled } from "@/lib/server/email-mode";

export async function runEmailLiveCheck(): Promise<ProofReport> {
  const checks: ProofCheck[] = [];
  const add = (name: string, status: ProofCheck["status"], detail: string) => {
    checks.push({ name, status, detail });
  };

  if (isEmailDisabled()) {
    add("EMAIL_DISABLED", "pass", "EMAIL_DISABLED=true — auth email explicitly off.");
    add("RESEND_API_KEY", "skip", "Not required when disabled.");
    add("DELIVERY_PROOF_FILE", "skip", "Not required when disabled.");
    return {
      verdict: "PASS",
      label: "PASS (EMAIL_DISABLED)",
      checks,
    };
  }

  const mode = getEmailMode();
  if (mode !== "resend") {
    add("RESEND_API_KEY", "blocked", "RESEND_API_KEY + EMAIL_FROM required when email enabled.");
    add("EMAIL_FROM", "blocked", "Set EMAIL_FROM to a verified Resend sender.");
    return { verdict: "DEPLOY_BLOCKED", label: "DEPLOY_BLOCKED", checks };
  }

  add("RESEND_API_KEY", "pass", "Present (never logged).");
  add("EMAIL_FROM", "pass", `Sender configured (${process.env.EMAIL_FROM?.includes("@") ? "format OK" : "check domain"}).`);

  const proofTo = process.env.VOICEMEMORY_EMAIL_PROOF_TO?.trim();
  if (proofTo) {
    try {
      const { Resend } = await import("resend");
      const resend = new Resend(process.env.RESEND_API_KEY!);
      const result = await resend.emails.send({
        from: process.env.EMAIL_FROM!,
        to: proofTo,
        subject: "VoiceMemory email proof",
        text: "Proof send from validate:email-live — safe to ignore.",
      });
      if (result.error) {
        add("OPTIONAL_PROOF_SEND", "fail", result.error.message);
      } else {
        add("OPTIONAL_PROOF_SEND", "pass", "Proof message accepted by Resend API.");
      }
    } catch (error) {
      add(
        "OPTIONAL_PROOF_SEND",
        "fail",
        error instanceof Error ? error.message : "Resend send failed",
      );
    }
  } else {
    add(
      "OPTIONAL_PROOF_SEND",
      "skip",
      "Set VOICEMEMORY_EMAIL_PROOF_TO for optional inbox proof (never sent by default).",
    );
  }

  const emailStatus = readJsonFile(EMAIL_STATUS_PATH);
  const fileOk =
    isFreshIsoDate(emailStatus?.verifiedAt) &&
    requireTruthy(emailStatus, ["deliveryVerified"]).length === 0;

  if (fileOk) {
    add("DELIVERY_PROOF_FILE", "pass", "Fresh email_delivery_proof_status.json.");
  } else {
    add(
      "DELIVERY_PROOF_FILE",
      "blocked",
      "Complete email_delivery_proof_status.json after real inbox delivery (copy from template).",
    );
  }

  const verdict = summarizeVerdict(checks);
  return {
    verdict: verdict === "DEPLOY_BLOCKED" ? "DEPLOY_BLOCKED" : verdict,
    label: verdict,
    checks,
  };
}

export function writeEmailLiveReport(report: ProofReport): void {
  const path = `${SPP20_DIR}/email_live_proof_report.md`;
  writeFileSync(
    path,
    [
      "# Email live proof report",
      "",
      `**At:** ${new Date().toISOString()}`,
      `**Verdict:** ${report.label}`,
      "",
      "| Check | Status | Detail |",
      "|-------|--------|--------|",
      ...report.checks.map((c) => `| ${c.name} | ${c.status} | ${c.detail} |`),
      "",
      "> API keys are never printed. Proof email only when VOICEMEMORY_EMAIL_PROOF_TO is set.",
      "",
    ].join("\n"),
  );
}
