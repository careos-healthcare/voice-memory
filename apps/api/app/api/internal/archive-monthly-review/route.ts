import { NextResponse, type NextRequest } from "next/server";

import {
  buildArchiveMonthlyReviewBody,
  sendArchiveMonthlyReviewEmail,
} from "@/lib/email/archive-monthly-review-email";
import { authorizeInternalPushApi } from "@/lib/push/internal-api-auth";
import {
  apiErrorFromException,
  apiErrorResponse,
} from "@/lib/server/api-error-response";
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
    return apiErrorResponse({
      code: "ARCHIVE_REVIEW_INVALID_JSON",
      route: "internal/archive-monthly-review",
      internalCategory: "validation",
    });
  }

  const email = body.email?.trim();
  const archiveUrl = body.archiveUrl?.trim();
  const review = body.review;

  if (!email || !email.includes("@")) {
    return apiErrorResponse({ code: "ARCHIVE_REVIEW_INVALID_EMAIL", route: "internal/archive-monthly-review" });
  }
  if (!archiveUrl) {
    return apiErrorResponse({ code: "ARCHIVE_REVIEW_URL_REQUIRED", route: "internal/archive-monthly-review" });
  }
  if (!review?.monthKey || review.reviewVersion !== 2) {
    return apiErrorResponse({ code: "ARCHIVE_REVIEW_INVALID", route: "internal/archive-monthly-review" });
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
    return apiErrorFromException(err, {
      code: "ARCHIVE_REVIEW_SEND_FAILED",
      route: "internal/archive-monthly-review",
      logEvent: "api_error",
    });
  }
}
