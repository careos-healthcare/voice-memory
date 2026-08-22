import { NextResponse } from "next/server";

import { GEMINI_LIVE_MODEL_ID } from "@/lib/gemini";
import {
  LIVE_INPUT_AUDIO_MIME,
  LIVE_OUTPUT_AUDIO_MIME,
  LIVE_SESSION_TTL_MS,
} from "@/lib/live-audio/constants";
import { buildProxyWebSocketUrl } from "@/lib/live-audio/proxy-url";
import { logLiveAudio } from "@/lib/live-audio/live-audio-log";
import { signLiveAudioSessionToken } from "@/lib/live-audio/session-token";
import { createVaultRecoverySecret } from "@/lib/live-audio/vault-recovery-secret";
import { registerVaultRecoverySession } from "@/lib/live-audio/vault-recovery-store";
import { guardLiveAudioSessionRoute } from "@/lib/server/live-audio-guard";
import { apiMethodNotAllowed } from "@/lib/server/api-error-response";
import { registerLiveAudioSession } from "@/lib/live-audio/session-store";
import {
  ipHashFromRequest,
  userAgentHashFromRequest,
} from "@/lib/server/request-identity";

export const runtime = "nodejs";

export async function GET() {
  return apiMethodNotAllowed({
    route: "/api/live-audio/session",
    methods: ["POST"],
    message: "Use POST to mint a short-lived live audio proxy session.",
    extra: {
      captureTokenHeader: "x-vm-capture-token",
      proxyWebSocketPath: "/api/live-audio/ws",
    },
  });
}

/** Mint a short-lived live audio proxy session — never returns GEMINI_API_KEY. */
export async function POST(request: Request) {
  const guard = await guardLiveAudioSessionRoute(request);
  if (!guard.ok) return guard.response;

  let systemInstruction: string | undefined;
  try {
    const body = (await request.json()) as Record<string, unknown>;
    const raw = body.systemInstruction;
    if (typeof raw === "string" && raw.trim()) {
      systemInstruction = raw.trim().slice(0, 12000);
    }
  } catch {
    // Empty body is valid — persona instructions are optional.
  }

  const binding = {
    ipHash: ipHashFromRequest(request),
    uaHash: userAgentHashFromRequest(request),
  };

  const { token, payload } = signLiveAudioSessionToken(guard.ctx.subject, binding);
  const vaultRecoverySecret = createVaultRecoverySecret();
  await registerLiveAudioSession({
    jti: payload.jti,
    sessionId: payload.sessionId,
    subject: payload.subject,
    ipHash: binding.ipHash,
    uaHash: binding.uaHash,
    systemInstruction,
  });
  registerVaultRecoverySession({
    sessionId: payload.sessionId,
    subject: payload.subject,
    vaultRecoverySecretBase64: vaultRecoverySecret,
  });

  logLiveAudio(
    `session minted sessionId=${payload.sessionId} subject=${payload.subject}`,
  );

  const origin = new URL(request.url).origin;

  return NextResponse.json({
    ok: true,
    sessionId: payload.sessionId,
    sessionToken: token,
    expiresAt: payload.exp,
    expiresInSeconds: Math.floor(LIVE_SESSION_TTL_MS / 1000),
    proxyWebSocketUrl: buildProxyWebSocketUrl(origin),
    model: GEMINI_LIVE_MODEL_ID,
    inputAudioMimeType: LIVE_INPUT_AUDIO_MIME,
    outputAudioMimeType: LIVE_OUTPUT_AUDIO_MIME,
    vaultRecoverySecret,
  });
}
