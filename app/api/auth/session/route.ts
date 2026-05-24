import { NextResponse } from "next/server";

import { getServerSession } from "@/lib/server/session";

export const runtime = "nodejs";

export async function GET() {
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
}
