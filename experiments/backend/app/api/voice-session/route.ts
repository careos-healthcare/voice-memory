import { ephemeralAiJson, logEphemeralAiFailure } from "@/lib/privacy/ephemeral-ai-response";
import { getOpenAIClient } from "@/lib/openai";
import { guardOpenAiRoute } from "@/lib/server/api-guard";
import { isAllowedVoiceSessionOrigin } from "@/lib/server/allowed-api-origin";
import {
  commitUsageReservation,
  releaseUsageReservation,
} from "@/lib/server/usage-reservation-store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const MODEL = process.env.VOICEMEMORY_OPENAI_REALTIME_MODEL ?? "gpt-realtime";
const SECRET_TTL_SECONDS = Math.max(
  10,
  Math.min(
    120,
    Number(process.env.VOICEMEMORY_VOICE_SESSION_SECRET_TTL_SECONDS ?? "30"),
  ),
);

const INSTRUCTIONS = [
  "You are ArchiveMe's real-time Memory Graph conversation guide.",
  "Be concise, warm, and epistemically humble. Never diagnose the user.",
  "When a response depends on the user's past, call query_memory_graph.",
  "Never claim to remember private history unless the local tool returned it.",
  "Treat tool results as private, session-only context and do not repeat sensitive details unless relevant.",
].join(" ");

export async function GET() {
  return ephemeralAiJson(
    {
      route: "/api/voice-session",
      methods: ["POST"],
      captureTokenHeader: "x-vm-capture-token",
      code: "METHOD_NOT_ALLOWED",
      error: "Use POST to mint a short-lived realtime client secret.",
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

  const guard = await guardOpenAiRoute(request, "analyze", {
    durationSeconds: 60,
  });
  if (!guard.ok) return guard.response;

  try {
    const clientSecret = await getOpenAIClient().realtime.clientSecrets.create({
      expires_after: {
        anchor: "created_at",
        seconds: SECRET_TTL_SECONDS,
      },
      session: {
        type: "realtime",
        model: MODEL,
        output_modalities: ["audio"],
        max_output_tokens: 1024,
        instructions: INSTRUCTIONS,
        audio: {
          input: {
            format: { type: "audio/pcm", rate: 24000 },
            noise_reduction: { type: "near_field" },
            transcription: { model: "gpt-4o-mini-transcribe" },
            turn_detection: { type: "semantic_vad" },
          },
          output: {
            format: { type: "audio/pcm", rate: 24000 },
            voice: "marin",
          },
        },
        tool_choice: "auto",
        tools: [
          {
            type: "function",
            name: "query_memory_graph",
            description:
              "Search the user's locally encrypted Memory Graph for relevant history. The client executes this tool locally.",
            parameters: {
              type: "object",
              additionalProperties: false,
              properties: {
                topic: {
                  type: "string",
                  description: "The person, theme, goal, habit, or event to retrieve.",
                },
                timeframe: {
                  type: "string",
                  description:
                    "Optional natural timeframe such as last 30 days, this year, or all time.",
                },
              },
              required: ["topic"],
            },
          },
        ],
        tracing: null,
      },
    });
    const reservationId = guard.ctx.monetization?.reservation?.reservationId;
    if (reservationId) await commitUsageReservation(reservationId, 1);

    return ephemeralAiJson({
      ok: true,
      provider: "openai",
      sessionId: clientSecret.session.id,
      clientSecret: clientSecret.value,
      expiresAt: clientSecret.expires_at,
      expiresInSeconds: SECRET_TTL_SECONDS,
      model: MODEL,
      voice: "marin",
      sampleRateHz: 24000,
      realtimeWebSocketUrl: `wss://api.openai.com/v1/realtime?model=${encodeURIComponent(MODEL)}`,
      via: guard.ctx.via,
    });
  } catch (error) {
    const reservationId = guard.ctx.monetization?.reservation?.reservationId;
    if (reservationId) await releaseUsageReservation(reservationId);
    logEphemeralAiFailure("/api/voice-session", error);
    return ephemeralAiJson(
      {
        error: "Realtime voice is temporarily unavailable.",
        code: "VOICE_SESSION_UNAVAILABLE",
      },
      { status: 503 },
    );
  }
}
