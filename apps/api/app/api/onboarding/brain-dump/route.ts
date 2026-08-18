import { NextResponse } from "next/server";

import {
  apiErrorFromException,
  apiErrorResponse,
} from "@/lib/server/api-error-response";
import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";
import { getServerSession } from "@/lib/server/session";

export const runtime = "nodejs";

const MAX_BRAIN_DUMP_BYTES = 50 * 1024 * 1024;
const MAX_BRAIN_DUMP_SECONDS = 300;

function assertPostgresAvailable(): void {
  if (!shouldUsePostgresStorage()) {
    throw new Error("DATABASE_URL is required to store brain dump uploads.");
  }
}

export async function POST(request: Request) {
  try {
    const session = await getServerSession();
    if (!session?.userId) {
      return apiErrorResponse({
        code: "AUTH_REQUIRED",
        logEvent: "auth_failure",
        internalCategory: "unauthenticated",
        route: "onboarding/brain-dump",
      });
    }

    const formData = await request.formData();
    const encryptedAudio = formData.get("encryptedAudio");
    const entryIdRaw = formData.get("entryId");
    const durationRaw = formData.get("durationSeconds");

    const entryId = typeof entryIdRaw === "string" ? entryIdRaw.trim() : "";
    const durationSeconds = Number(durationRaw ?? 0);

    if (!(encryptedAudio instanceof File) || encryptedAudio.size === 0) {
      return apiErrorResponse({ code: "AUDIO_REQUIRED", route: "onboarding/brain-dump" });
    }
    if (!entryId) {
      return apiErrorResponse({ code: "ENTRY_ID_REQUIRED", route: "onboarding/brain-dump" });
    }
    if (
      !Number.isFinite(durationSeconds) ||
      durationSeconds <= 0 ||
      durationSeconds > MAX_BRAIN_DUMP_SECONDS
    ) {
      return apiErrorResponse({ code: "DURATION_LIMIT", route: "onboarding/brain-dump" });
    }
    if (encryptedAudio.size > MAX_BRAIN_DUMP_BYTES) {
      return apiErrorResponse({ code: "PAYLOAD_TOO_LARGE", route: "onboarding/brain-dump" });
    }

    assertPostgresAvailable();

    await dbQuery(
      `INSERT INTO brain_dump_uploads (user_id, entry_id, duration_seconds, encrypted_bytes)
       VALUES ($1, $2, $3, $4)`,
      [session.userId, entryId, Math.round(durationSeconds), encryptedAudio.size],
    );

    return NextResponse.json({ ok: true, entryId });
  } catch (error) {
    console.error("onboarding/brain-dump failed", error);
    return apiErrorFromException(error, {
      code: "BRAIN_DUMP_UPLOAD_FAILED",
      route: "onboarding/brain-dump",
      logEvent: "api_error",
    });
  }
}
