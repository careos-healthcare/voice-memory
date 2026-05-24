import { NextResponse } from "next/server";

import { getServerSession } from "@/lib/server/session";
import { readEncryptedBlobs } from "@/lib/server/sync-store";

export const runtime = "nodejs";

export async function GET() {
  const session = await getServerSession();
  if (!session) {
    return NextResponse.json({ error: "Sign in required." }, { status: 401 });
  }

  const blobs = readEncryptedBlobs(session.userId).map((blob) => ({
    id: blob.id,
    type: blob.type,
    encrypted: blob.encrypted,
    updatedAt: blob.updatedAt,
    byteLength: blob.byteLength,
  }));

  return NextResponse.json({ blobs });
}
