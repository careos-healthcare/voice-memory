import { NextResponse } from "next/server";

import { getServerSession } from "@/lib/server/session";
import {
  deleteSyncRecovery,
  readSyncRecovery,
  upsertSyncRecovery,
} from "@/lib/server/sync-recovery-store";
import { parseSyncRecoveryEnvelope } from "@/lib/sync/recovery-envelope-contract";

export const runtime = "nodejs";

const MAX_BODY_BYTES = 16 * 1024;
const RATE_WINDOW_MS = 60_000;
const RATE_LIMIT = 12;
const globalRate = globalThis as typeof globalThis & {
  __syncRecoveryRate?: Record<string, number[]>;
};

function unauthorized(): NextResponse {
  return NextResponse.json(
    { error: "Sign in required.", code: "AUTH_REQUIRED" },
    { status: 401 },
  );
}

function rateLimited(userId: string): boolean {
  const now = Date.now();
  globalRate.__syncRecoveryRate ??= {};
  const recent = (globalRate.__syncRecoveryRate[userId] ?? []).filter(
    (timestamp) => timestamp > now - RATE_WINDOW_MS,
  );
  if (recent.length >= RATE_LIMIT) {
    globalRate.__syncRecoveryRate[userId] = recent;
    return true;
  }
  recent.push(now);
  globalRate.__syncRecoveryRate[userId] = recent;
  return false;
}

export async function GET(request: Request) {
  const session = await getServerSession();
  if (!session) return unauthorized();
  if (rateLimited(session.userId)) {
    return NextResponse.json(
      { error: "Too many recovery requests.", code: "RATE_LIMITED" },
      { status: 429 },
    );
  }
  const envelope = await readSyncRecovery(session.userId);
  const statusOnly = new URL(request.url).searchParams.get("status") === "1";
  if (statusOnly) {
    return NextResponse.json({
      enabled: envelope !== null,
      ...(envelope
        ? {
            envelopeRevision: envelope.envelopeRevision,
            keyEpoch: envelope.keyEpoch,
            updatedAt: envelope.updatedAt,
          }
        : {}),
    });
  }
  return NextResponse.json({ envelope });
}

export async function POST(request: Request) {
  const session = await getServerSession();
  if (!session) return unauthorized();
  if (rateLimited(session.userId)) {
    return NextResponse.json(
      { error: "Too many recovery requests.", code: "RATE_LIMITED" },
      { status: 429 },
    );
  }
  const declaredLength = Number(request.headers.get("content-length") ?? "0");
  if (declaredLength > MAX_BODY_BYTES) {
    return NextResponse.json(
      { error: "Recovery envelope is too large.", code: "PAYLOAD_TOO_LARGE" },
      { status: 413 },
    );
  }
  const raw = await request.text();
  if (Buffer.byteLength(raw, "utf8") > MAX_BODY_BYTES) {
    return NextResponse.json(
      { error: "Recovery envelope is too large.", code: "PAYLOAD_TOO_LARGE" },
      { status: 413 },
    );
  }
  let body: unknown;
  try {
    body = JSON.parse(raw);
  } catch {
    return NextResponse.json(
      { error: "Invalid recovery envelope.", code: "INVALID_ENVELOPE" },
      { status: 400 },
    );
  }
  const envelope = parseSyncRecoveryEnvelope(
    (body as { envelope?: unknown } | null)?.envelope,
    session.userId,
  );
  if (!envelope) {
    return NextResponse.json(
      { error: "Invalid recovery envelope.", code: "INVALID_ENVELOPE" },
      { status: 400 },
    );
  }
  try {
    const result = await upsertSyncRecovery(session.userId, envelope);
    return NextResponse.json({
      ok: true,
      result,
      envelopeRevision: envelope.envelopeRevision,
    });
  } catch (error) {
    const code = error instanceof Error ? error.message : "";
    if (code === "STALE_RECOVERY_ENVELOPE" || code === "RECOVERY_REVISION_CONFLICT") {
      return NextResponse.json(
        { error: "Recovery envelope revision rejected.", code },
        { status: 409 },
      );
    }
    return NextResponse.json(
      { error: "Recovery envelope could not be saved.", code: "RECOVERY_SAVE_FAILED" },
      { status: 500 },
    );
  }
}

export async function DELETE() {
  const session = await getServerSession();
  if (!session) return unauthorized();
  if (rateLimited(session.userId)) {
    return NextResponse.json(
      { error: "Too many recovery requests.", code: "RATE_LIMITED" },
      { status: 429 },
    );
  }
  await deleteSyncRecovery(session.userId);
  return NextResponse.json({ ok: true });
}
