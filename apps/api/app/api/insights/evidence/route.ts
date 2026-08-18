import { NextResponse } from "next/server";
import { randomUUID } from "node:crypto";

import { isGeminiConfigured } from "@/lib/gemini";
import { generateEvidenceBackedInsight } from "@/src/services/insights/generator";
import { ingestTranscriptChunk } from "@/src/services/ledger/ingest";
import { MAX_TRANSCRIPT_CHARS } from "@/lib/server/api-guard";
import {
  apiErrorFromException,
  apiErrorResponse,
} from "@/lib/server/api-error-response";
import { getServerSession } from "@/lib/server/session";
import { normalizeLifeStageLens } from "@/types/user-context";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    if (!isGeminiConfigured()) {
      return apiErrorResponse({ code: "GEMINI_NOT_CONFIGURED", route: "insights/evidence" });
    }

    if (!process.env.OPENAI_API_KEY?.trim()) {
      return apiErrorResponse({ code: "OPENAI_NOT_CONFIGURED", route: "insights/evidence" });
    }

    const session = await getServerSession();
    if (!session?.userId) {
      return apiErrorResponse({
        code: "AUTH_REQUIRED",
        logEvent: "auth_failure",
        internalCategory: "unauthenticated",
        route: "insights/evidence",
      });
    }

    let body: { transcript?: string; entryId?: string; activeLens?: string };
    try {
      body = (await request.json()) as typeof body;
    } catch {
      return apiErrorResponse({
        code: "INVALID_REQUEST",
        route: "insights/evidence",
        internalCategory: "validation",
      });
    }

    const transcript = body.transcript?.trim() ?? "";
    if (!transcript) {
      return apiErrorResponse({ code: "TRANSCRIPT_REQUIRED", route: "insights/evidence" });
    }
    if (transcript.length > MAX_TRANSCRIPT_CHARS) {
      return apiErrorResponse({ code: "TRANSCRIPT_TOO_LONG", route: "insights/evidence" });
    }

    const entryId = body.entryId?.trim() || randomUUID();
    const insightId = randomUUID();

    await ingestTranscriptChunk(session.userId, entryId, transcript);

    const insight = await generateEvidenceBackedInsight(session.userId, transcript, {
      activeLens: normalizeLifeStageLens(body.activeLens),
    });

    return NextResponse.json({
      ok: true,
      entryId,
      insight: {
        id: insightId,
        insightText: insight.insightText,
        kind: insight.kind,
        confidenceBand: insight.confidenceBand,
        citedEntryIds: insight.citedEntryIds,
      },
    });
  } catch (error) {
    console.error("insights/evidence failed", error);
    return apiErrorFromException(error, {
      code: "INSIGHT_GENERATION_FAILED",
      route: "insights/evidence",
      logEvent: "api_error",
    });
  }
}
