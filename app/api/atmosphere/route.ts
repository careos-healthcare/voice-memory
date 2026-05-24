import { NextResponse } from "next/server";

import { getOpenAIClient } from "@/lib/openai";
import type { AtmosphereStyle } from "@/types/atmosphere";

export const runtime = "nodejs";

const GUARDRAIL_SUFFIX =
  " Abstract only. No people, no faces, no figures, no text, no narrative scene, no cinematic trauma, no fantasy.";

function isApiEnabled(): boolean {
  return (
    process.env.VOICEMEMORY_ENABLE_ATMOSPHERE_API === "true" &&
    Boolean(process.env.OPENAI_API_KEY)
  );
}

/** Optional image API — returns fallback signal when unavailable. Never automatic. */
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

  if (!isApiEnabled()) {
    return NextResponse.json({ source: "fallback", reason: "api_disabled" });
  }

  try {
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
      return NextResponse.json({ source: "fallback", reason: "empty_response" });
    }

    return NextResponse.json({
      source: "api",
      dataBase64: data,
      width: 1024,
      height: 1024,
    });
  } catch {
    return NextResponse.json({ source: "fallback", reason: "generation_failed" });
  }
}
