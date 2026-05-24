import { NextResponse } from "next/server";

import { getServerSession } from "@/lib/server/session";
import { readSyncManifest } from "@/lib/server/sync-store";

export const runtime = "nodejs";

/** Metadata only — ciphertext sizes and timestamps, never plaintext. */
export async function GET() {
  const session = await getServerSession();
  if (!session) {
    return NextResponse.json({ error: "Sign in required." }, { status: 401 });
  }

  return NextResponse.json(readSyncManifest(session.userId));
}
