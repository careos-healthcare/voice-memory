import { NextResponse } from "next/server";

import { logAuthError } from "@/lib/server/auth-diagnostics";
import { getServerSession } from "@/lib/server/session";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const session = await getServerSession();
    if (!session) {
      return NextResponse.json({ session: null });
    }

    return NextResponse.json({
      session: {
        user: { id: session.userId, email: session.email },
        signedInAt: new Date().toISOString(),
      },
    });
  } catch (error) {
    logAuthError("session", error);
    return NextResponse.json(
      { error: "Session lookup failed.", code: "AUTH_SESSION_FAILED" },
      { status: 503 },
    );
  }
}
