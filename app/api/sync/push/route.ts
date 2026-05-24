import { NextResponse } from "next/server";

import { getServerSession } from "@/lib/server/session";
import { upsertEncryptedBlobs } from "@/lib/server/sync-store";
import type { EncryptedPayload, SyncBlobType } from "@/types/sync";

export const runtime = "nodejs";

interface PushBody {
  blobs?: Array<{
    id: string;
    type: SyncBlobType;
    encrypted: EncryptedPayload;
    updatedAt: string;
    byteLength: number;
  }>;
}

/** Accept encrypted blobs only — reject plaintext archive fields. */
export async function POST(request: Request) {
  const session = await getServerSession();
  if (!session) {
    return NextResponse.json({ error: "Sign in required." }, { status: 401 });
  }

  const body = (await request.json()) as PushBody;
  const blobs = body.blobs ?? [];
  if (blobs.length === 0) {
    return NextResponse.json({ error: "No encrypted blobs provided." }, { status: 400 });
  }

  for (const blob of blobs) {
    if (!blob.id || !blob.type || !blob.encrypted?.ciphertext || !blob.encrypted?.iv) {
      return NextResponse.json({ error: "Invalid encrypted blob envelope." }, { status: 400 });
    }
    if (blob.encrypted.version !== 1) {
      return NextResponse.json({ error: "Unsupported encryption version." }, { status: 400 });
    }
  }

  const manifest = upsertEncryptedBlobs(
    session.userId,
    blobs.map((blob) => ({
      id: blob.id,
      type: blob.type,
      encrypted: blob.encrypted,
      updatedAt: blob.updatedAt,
      byteLength: blob.byteLength,
    })),
  );

  return NextResponse.json({ ok: true, manifest });
}
