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
import { registerLiveAudioSession } from "@/lib/live-audio/session-store";
import {
  ipHashFromRequest,
  userAgentHashFromRequest,
} from "@/lib/server/request-identity";

export const runtime = "nodejs";

export async function GET() {
  return NextResponse.json(
    {
      route: "/api/live-audio/session",
      methods: ["POST"],
      captureTokenHeader: "x-vm-capture-token",
      proxyWebSocketPath: "/api/live-audio/ws",
      code: "METHOD_NOT_ALLOWED",
      error: "Use POST to mint a short-lived live audio proxy session.",
    },
    { status: 405 },
  );
}

/** Mint a short-lived live audio proxy session — never returns GEMINI_API_KEY. */
export async function POST(request: Request) {
  const guard = await guardLiveAudioSessionRoute(request);
  if (!guard.ok) return guard.response;

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
