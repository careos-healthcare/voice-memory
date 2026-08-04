import "server-only";

import { Resend } from "resend";

import { readAuthEmailEnvStatus } from "@/lib/server/env-check";
import type { ArchiveMonthlyReview } from "@/types/archive-synthesis";

export interface SendArchiveMonthlyReviewEmailInput {
  email: string;
  review: ArchiveMonthlyReview;
  /** Deep link into archive (web or universal). */
  archiveUrl: string;
}

export interface SendArchiveMonthlyReviewEmailResult {
  resendResponseId: string | null;
  subject: string;
}

function isProduction(): boolean {
  return process.env.NODE_ENV === "production";
}

function pickStrongestTheory(review: ArchiveMonthlyReview): string | null {
  const emerging = review.emergingTheories[0]?.statement?.trim();
  if (emerging) return emerging;
  const changed = review.whatChanged[0]?.statement?.trim();
  return changed || null;
}

function pickBiggestChange(review: ArchiveMonthlyReview): string | null {
  const line = review.whatChanged[0]?.statement?.trim();
  if (line) return line;
  const faded = review.fadingTheories[0]?.statement?.trim();
  return faded || null;
}

function pickSurprise(review: ArchiveMonthlyReview): string | null {
  const big = review.biggestSurprise?.statement?.trim();
  if (big) return big;
  return review.surprises[0]?.statement?.trim() || null;
}

export function buildArchiveMonthlyReviewSubject(
  review: ArchiveMonthlyReview,
): string {
  if (review.biggestSurprise?.statement?.trim()) {
    return "The archive noticed something new";
  }
  const strengthened = review.emergingTheories[0]?.statement?.trim();
  if (strengthened) {
    return "A belief strengthened this month";
  }
  return "Your archive changed this month";
}

export function buildArchiveMonthlyReviewBody(
  input: SendArchiveMonthlyReviewEmailInput,
): string {
  const { review, archiveUrl } = input;
  const strongest = pickStrongestTheory(review);
  const change = pickBiggestChange(review);
  const surprise = pickSurprise(review);

  const lines: string[] = [
    "Your ArchiveMe monthly archive review",
    "",
    `Month: ${review.monthKey}`,
    `Saved moments in archive: ${review.eligibleCount}`,
    "",
  ];

  if (strongest) {
    lines.push("Strongest theory this month", strongest, "");
  }
  if (change) {
    lines.push("Biggest change", change, "");
  }
  if (surprise) {
    lines.push("Surprise", surprise, "");
  }

  lines.push(
    "Open your archive",
    archiveUrl,
    "",
    "This summary was generated from your existing archive synthesis — not a separate analysis pass.",
    "",
    "— ArchiveMe",
  );

  return lines.join("\n");
}

/** Send monthly archive review — uses cached GPT-5 synthesis output only. */
export async function sendArchiveMonthlyReviewEmail(
  input: SendArchiveMonthlyReviewEmailInput,
): Promise<SendArchiveMonthlyReviewEmailResult> {
  const env = readAuthEmailEnvStatus();
  const apiKey = process.env.RESEND_API_KEY?.trim() ?? "";
  const from = process.env.EMAIL_FROM?.trim() ?? "";
  const subject = buildArchiveMonthlyReviewSubject(input.review);
  const text = buildArchiveMonthlyReviewBody(input);

  if (!isProduction()) {
    return { resendResponseId: null, subject };
  }

  if (!apiKey || !from || !env.emailFromFormatValid) {
    throw new Error("Resend email is not configured for monthly archive review.");
  }

  const resend = new Resend(apiKey);
  const { data, error } = await resend.emails.send({
    from,
    to: [input.email.trim()],
    subject,
    text,
  });

  if (error) {
    throw new Error(error.message ?? "Resend rejected monthly review send.");
  }

  return {
    resendResponseId: data?.id ?? null,
    subject,
  };
}
