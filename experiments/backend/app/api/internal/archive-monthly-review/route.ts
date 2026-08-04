import { NextResponse, type NextRequest } from "next/server";

import {
  buildArchiveMonthlyReviewBody,
  sendArchiveMonthlyReviewEmail,
} from "@/lib/email/archive-monthly-review-email";
import { authorizeInternalPushApi } from "@/lib/push/internal-api-auth";
import type { ArchiveMonthlyReview } from "@/types/archive-synthesis";

export const runtime = "nodejs";

interface SendMonthlyReviewRequest {
  email: string;
  review: ArchiveMonthlyReview;
  archiveUrl: string;
  /** When true, returns rendered body without sending (dev / QA). */
  dryRun?: boolean;
}

/** Send archive monthly review email from cached synthesis — internal / cron only. */
export async function POST(request: NextRequest) {
  const auth = await authorizeInternalPushApi(request);
  if (!auth.authorized) return auth.response;

  let body: SendMonthlyReviewRequest;
  try {
    body = (await request.json()) as SendMonthlyReviewRequest;
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }

  const email = body.email?.trim();
  const archiveUrl = body.archiveUrl?.trim();
  const review = body.review;

  if (!email || !email.includes("@")) {
    return NextResponse.json(
      { error: "Valid email required" },
      { status: 400 },
    );
  }
  if (!archiveUrl) {
    return NextResponse.json({ error: "archiveUrl required" }, { status: 400 });
  }
  if (!review?.monthKey || review.reviewVersion !== 4) {
    return NextResponse.json(
      { error: "review must be ArchiveMonthlyReview v4 from synthesis cache" },
      { status: 400 },
    );
  }

  if (body.dryRun) {
    return NextResponse.json({
      ok: true,
      dryRun: true,
      preview: buildArchiveMonthlyReviewBody({ email, review, archiveUrl }),
    });
  }

  try {
    const result = await sendArchiveMonthlyReviewEmail({
      email,
      review,
      archiveUrl,
    });
    return NextResponse.json({
      ok: true,
      subject: result.subject,
      resendResponseId: result.resendResponseId,
    });
  } catch (err) {
    console.error("[internal/archive-monthly-review]", err);
    const message = err instanceof Error ? err.message : "Send failed";
    return NextResponse.json({ error: message }, { status: 502 });
  }
}
