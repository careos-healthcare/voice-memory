import { NextResponse } from "next/server";

import { apiPayloadTooLarge } from "@/lib/server/api-guard";
import { apiErrorResponse } from "@/lib/server/api-error-response";
import { MAX_AUDIO_BYTES } from "@/lib/server/api-limits";
import { getServerSession } from "@/lib/server/session";
import {
  audioQrPlayerHtml,
  audioQrSecret,
  createAudioQrLink,
  defaultAudioQrStore,
  verifyAudioQrToken,
  type AudioQrStore,
} from "../../../../src/routes/export/audio-qr";

export const runtime = "nodejs";

const store: AudioQrStore = defaultAudioQrStore();

export async function POST(request: Request) {
  const session = await getServerSession();
  if (!session) {
    return apiErrorResponse({
      code: "AUTH_REQUIRED",
      status: 401,
      logEvent: "auth_failure",
      internalCategory: "unauthenticated",
      route: "export/audio-qr",
    });
  }

  const formData = await request.formData();
  const audio = formData.get("audio");
  const nonce = formData.get("nonce");
  const mac = formData.get("mac");
  if (!(audio instanceof File) || audio.size === 0) {
    return apiErrorResponse({
      code: "AUDIO_REQUIRED",
      status: 400,
      route: "export/audio-qr",
    });
  }
  if (audio.size > MAX_AUDIO_BYTES) {
    return apiPayloadTooLarge(
      `Audio must be under ${Math.round(MAX_AUDIO_BYTES / (1024 * 1024))}MB.`,
    );
  }
  if (typeof nonce !== "string" || typeof mac !== "string") {
    return apiErrorResponse({
      code: "AUDIO_REQUIRED",
      status: 400,
      route: "export/audio-qr",
    });
  }

  const created = await createAudioQrLink({
    userId: session.userId,
    ciphertext: Buffer.from(await audio.arrayBuffer()),
    nonce,
    mac,
    origin: new URL(request.url).origin,
    store,
  });
  if ("error" in created) {
    if (created.error === "too_large") {
      return apiPayloadTooLarge(
        `Audio must be under ${Math.round(MAX_AUDIO_BYTES / (1024 * 1024))}MB.`,
      );
    }
    return apiErrorResponse({
      code: "AUDIO_REQUIRED",
      status: 400,
      route: "export/audio-qr",
    });
  }
  return NextResponse.json(created);
}

export async function GET(request: Request) {
  const token = new URL(request.url).searchParams.get("t") ?? "";
  const secret = audioQrSecret();
  const verified = token ? verifyAudioQrToken(token, secret) : null;
  const record = verified ? await store.get(verified.id) : null;
  if (!record) {
    return new NextResponse("This recording link has expired.", {
      status: 404,
      headers: { "Cache-Control": "no-store" },
    });
  }
  const raw = new URL(request.url).searchParams.get("raw") === "1";
  if (raw) {
    return new NextResponse(new Uint8Array(record.ciphertext), {
      headers: {
        "Content-Type": "application/octet-stream",
        "Cache-Control": "private, no-store",
        "X-Audio-Nonce": record.nonce,
        "X-Audio-Mac": record.mac,
      },
    });
  }
  return new NextResponse(audioQrPlayerHtml(), {
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}
