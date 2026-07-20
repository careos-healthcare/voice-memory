import type { IncomingMessage } from "node:http";

import {
  hashRequestIdentity,
  isE2eTestIpHeaderAllowed,
  VOICEMEMORY_TEST_IP_HEADER,
} from "@/lib/capture/request-ip";
import { LIVE_SESSION_TOKEN_QUERY_PARAM } from "@/lib/live-audio/constants";
import {
  verifyLiveAudioSessionToken,
  type LiveAudioSessionPayload,
} from "@/lib/live-audio/session-token";
import { consumeLiveAudioSession } from "@/lib/live-audio/session-store";

export type LiveAudioWsAuthResult =
  | { ok: true; sessionId: string; subject: string; payload: LiveAudioSessionPayload }
  | { ok: false; code: string; message: string; httpStatus: number };

function headerValue(
  request: IncomingMessage,
  name: string,
): string | undefined {
  const raw = request.headers[name.toLowerCase()];
  if (Array.isArray(raw)) return raw[0];
  return raw;
}

function clientIpFromIncomingMessage(request: IncomingMessage): string {
  if (isE2eTestIpHeaderAllowed()) {
    const testIp = headerValue(request, VOICEMEMORY_TEST_IP_HEADER)?.trim();
    if (testIp && testIp.length <= 128 && /^[\w.\-:]+$/.test(testIp)) {
      return testIp;
    }
  }

  const forwarded = headerValue(request, "x-forwarded-for");
  if (forwarded) {
    const first = forwarded.split(",")[0]?.trim();
    if (first) return first;
  }

  const realIp = headerValue(request, "x-real-ip")?.trim();
  if (realIp) return realIp;

  return request.socket.remoteAddress ?? "unknown";
}

export function ipHashFromIncomingMessage(request: IncomingMessage): string {
  return hashRequestIdentity(clientIpFromIncomingMessage(request));
}

export function userAgentHashFromIncomingMessage(
  request: IncomingMessage,
): string {
  const ua = headerValue(request, "user-agent") ?? "unknown";
  return hashRequestIdentity(ua);
}

function readSessionToken(
  query: Record<string, string | string[] | undefined>,
): string | null {
  const raw = query[LIVE_SESSION_TOKEN_QUERY_PARAM];
  if (typeof raw === "string" && raw.trim().length > 0) {
    return raw.trim();
  }
  if (Array.isArray(raw)) {
    const first = raw.find((value) => value.trim().length > 0);
    return first?.trim() ?? null;
  }
  return null;
}

/** Validates a minted session ticket before accepting a WebSocket upgrade. */
export async function authenticateLiveAudioWebSocketRequest(input: {
  query: Record<string, string | string[] | undefined>;
  ipHash: string;
  uaHash: string;
  isGeminiConfigured: () => boolean;
  isGeminiKillSwitchActive: () => boolean;
}): Promise<LiveAudioWsAuthResult> {
  if (input.isGeminiKillSwitchActive()) {
    return {
      ok: false,
      code: "GEMINI_DISABLED",
      message: "Live voice is temporarily unavailable.",
      httpStatus: 429,
    };
  }

  if (!input.isGeminiConfigured()) {
    return {
      ok: false,
      code: "GEMINI_NOT_CONFIGURED",
      message: "Live voice is not configured on this server.",
      httpStatus: 503,
    };
  }

  const token = readSessionToken(input.query);
  if (!token) {
    return {
      ok: false,
      code: "MISSING_SESSION_TOKEN",
      message: "sessionToken query parameter is required.",
      httpStatus: 401,
    };
  }

  const payload = verifyLiveAudioSessionToken(token, {
    ipHash: input.ipHash,
    uaHash: input.uaHash,
  });
  if (!payload) {
    return {
      ok: false,
      code: "INVALID_SESSION_TOKEN",
      message: "Live audio session token is invalid or expired.",
      httpStatus: 401,
    };
  }

  const consumed = await consumeLiveAudioSession({
    jti: payload.jti,
    ipHash: input.ipHash,
    uaHash: input.uaHash,
  });
  if (!consumed.ok) {
    const message =
      consumed.reason === "consumed"
        ? "Live audio session token was already used."
        : consumed.reason === "binding_mismatch"
          ? "Live audio session token binding mismatch."
          : "Live audio session token is unknown.";
    return {
      ok: false,
      code: "SESSION_NOT_AVAILABLE",
      message,
      httpStatus: 401,
    };
  }

  return {
    ok: true,
    sessionId: consumed.sessionId,
    subject: consumed.subject,
    payload,
  };
}

export function authenticateLiveAudioWebSocketUpgrade(
  request: IncomingMessage,
  query: Record<string, string | string[] | undefined>,
  deps: {
    isGeminiConfigured: () => boolean;
    isGeminiKillSwitchActive: () => boolean;
  },
): Promise<LiveAudioWsAuthResult> {
  return authenticateLiveAudioWebSocketRequest({
    query,
    ipHash: ipHashFromIncomingMessage(request),
    uaHash: userAgentHashFromIncomingMessage(request),
    isGeminiConfigured: deps.isGeminiConfigured,
    isGeminiKillSwitchActive: deps.isGeminiKillSwitchActive,
  });
}
