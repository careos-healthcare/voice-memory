import { NextResponse } from "next/server";

import {
  apiPayloadTooLarge,
  guardOpenAiRoute,
  MAX_ATMOSPHERE_PROMPT_CHARS,
  type ApiGuardContext,
} from "@/lib/server/api-guard";
import { getOpenAIClient } from "@/lib/openai";
import {
  meterBestEffort,
  vendorRequestId,
} from "@/lib/server/unit-economics-meter";
import type { AtmosphereStyle } from "@/types/atmosphere";
import { releaseUsageReservation } from "@/lib/server/usage-reservation-store";

export const runtime = "nodejs";

const GUARDRAIL_SUFFIX =
  " Abstract only. No people, no faces, no figures, no text, no narrative scene, no cinematic trauma, no fantasy.";

function isApiEnabled(): boolean {
  return (
    process.env.VOICEMEMORY_ENABLE_ATMOSPHERE_API === "true" &&
    Boolean(process.env.OPENAI_API_KEY)
  );
}

/** Optional image API — gated; returns fallback when unavailable. */
export async function POST(request: Request) {
  let body: { prompt?: string; style?: AtmosphereStyle };
  try {
    body = (await request.json()) as { prompt?: string; style?: AtmosphereStyle };
  } catch {
    return NextResponse.json({ source: "fallback", reason: "invalid_body" }, { status: 400 });
  }

  const prompt = body.prompt?.trim();
  if (!prompt) {
    return NextResponse.json({ source: "fallback", reason: "missing_prompt" }, { status: 400 });
  }

  if (prompt.length > MAX_ATMOSPHERE_PROMPT_CHARS) {
    return apiPayloadTooLarge(
      `Prompt must be under ${MAX_ATMOSPHERE_PROMPT_CHARS} characters.`,
    );
  }

  if (!isApiEnabled()) {
    return NextResponse.json({ source: "fallback", reason: "api_disabled" });
  }

  let guardContext: ApiGuardContext | undefined;
  try {
    const guard = await guardOpenAiRoute(request, "atmosphere");
    if (!guard.ok) return guard.response;
    guardContext = guard.ctx;
    const client = getOpenAIClient();
    const result = await client.images.generate({
      model: "dall-e-3",
      prompt: `${prompt}${GUARDRAIL_SUFFIX}`,
      size: "1024x1024",
      response_format: "b64_json",
      n: 1,
    });
    const data = result.data?.[0]?.b64_json;
    if (!data) {
      const reservationId = guardContext.monetization?.reservation?.reservationId;
      if (reservationId) await releaseUsageReservation(reservationId);
      return NextResponse.json({ source: "fallback", reason: "empty_response" });
    }
    await meterBestEffort({
      operation: "atmosphere.image",
      subject: guardContext,
      idempotencyKey: vendorRequestId(
        result,
        request.headers.get("x-vm-idempotency-key"),
      ),
      metric: "image_generations",
      resource: "image.atmosphere",
      quantity: 1,
      measurementBasis: "exact",
      dimensions: { provider: "openai" },
    });

    return NextResponse.json({
      source: "api",
      dataBase64: data,
      width: 1024,
      height: 1024,
    });
  } catch {
    const reservationId = guardContext?.monetization?.reservation?.reservationId;
    if (reservationId) await releaseUsageReservation(reservationId);
    return NextResponse.json({ source: "fallback", reason: "generation_failed" });
  }
}
