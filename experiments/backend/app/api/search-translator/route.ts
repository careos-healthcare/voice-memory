import { getOpenAIClient } from "@/lib/openai";
import {
  ephemeralAiJson,
  logEphemeralAiFailure,
} from "@/lib/privacy/ephemeral-ai-response";
import {
  normalizeSearchIntentTimeframe,
  parseSearchIntent,
  parseSearchTranslatorRequest,
  SearchIntentSchema,
} from "@/lib/search-translator/search-intent-contract";
import { guardOpenAiRoute } from "@/lib/server/api-guard";
import { isAllowedVoiceSessionOrigin } from "@/lib/server/allowed-api-origin";
import {
  commitUsageReservation,
  releaseUsageReservation,
} from "@/lib/server/usage-reservation-store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const MAX_BODY_BYTES = 2_048;

export async function GET() {
  return ephemeralAiJson(
    {
      route: "/api/search-translator",
      methods: ["POST"],
      captureTokenHeader: "x-vm-capture-token",
      code: "METHOD_NOT_ALLOWED",
      error: "Use POST to translate a natural-language search query.",
    },
    { status: 405 },
  );
}

export async function POST(request: Request) {
  if (!isAllowedVoiceSessionOrigin(request)) {
    return ephemeralAiJson(
      {
        error: "Request origin is not permitted.",
        code: "ORIGIN_NOT_ALLOWED",
      },
      { status: 403 },
    );
  }

  const rawBody = await request.text();
  if (rawBody.length > MAX_BODY_BYTES) {
    return ephemeralAiJson(
      { error: "Search query is too large.", code: "PAYLOAD_TOO_LARGE" },
      { status: 413 },
    );
  }

  let query: string;
  try {
    query = parseSearchTranslatorRequest(JSON.parse(rawBody));
  } catch (error) {
    return ephemeralAiJson(
      {
        error: error instanceof Error ? error.message : "Invalid request.",
        code: "INVALID_REQUEST",
      },
      { status: 400 },
    );
  }

  const guard = await guardOpenAiRoute(request, "analyze", {
    transcriptChars: query.length,
  });
  if (!guard.ok) return guard.response;

  try {
    const now = new Date();
    const completion = await getOpenAIClient().chat.completions.create({
      model:
        process.env.VOICEMEMORY_SEARCH_TRANSLATOR_MODEL ?? "gpt-4o-mini",
      temperature: 0,
      messages: [
        {
          role: "system",
          content: [
            "Translate only the supplied search query into local search intent.",
            "You have no access to journal entries or Memory Graph data.",
            "Keep semantic_query concise and preserve named entities.",
            "Resolve temporal expressions into an inclusive UTC start and exclusive UTC end.",
            "Return null timeframe when the query has no temporal constraint.",
            "Do not infer diagnoses or facts about the user.",
            `Current UTC time: ${now.toISOString()}.`,
          ].join(" "),
        },
        { role: "user", content: query },
      ],
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "archive_me_search_intent",
          strict: true,
          schema: SearchIntentSchema,
        },
      },
    });
    const reservationId = guard.ctx.monetization?.reservation?.reservationId;
    const content = completion.choices[0]?.message.content;
    if (!content) throw new Error("Search translator returned no content.");
    const translated = parseSearchIntent(JSON.parse(content));
    if (reservationId) await commitUsageReservation(reservationId, 1);
    return ephemeralAiJson({
      ok: true,
      intent: normalizeSearchIntentTimeframe(translated, query, now),
    });
  } catch (error) {
    const reservationId = guard.ctx.monetization?.reservation?.reservationId;
    if (reservationId) await releaseUsageReservation(reservationId);
    logEphemeralAiFailure("/api/search-translator", error);
    return ephemeralAiJson(
      {
        error: "Natural-language search translation is temporarily unavailable.",
        code: "SEARCH_TRANSLATOR_UNAVAILABLE",
      },
      { status: 503 },
    );
  }
}
