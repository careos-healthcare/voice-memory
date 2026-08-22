import "server-only";

import { NextResponse } from "next/server";

import { debugAccessToken, hasFounderDebugCookie, isFounderEmail } from "@/lib/server/founder-access";
import { isInternalSurfaceEnabled } from "@/lib/server/internal-access";
import { getServerSession } from "@/lib/server/session";

export async function authorizeInternalPushApi(
  request: { headers: { get(name: string): string | null } },
): Promise<{ authorized: true } | { authorized: false; response: NextResponse }> {
  if (!isInternalSurfaceEnabled()) {
    return { authorized: false, response: new NextResponse(null, { status: 404 }) };
  }

  const headerToken = request.headers.get("x-vm-debug-token")?.trim();
  const expected = debugAccessToken();
  if (expected && headerToken && headerToken === expected) {
    return { authorized: true };
  }

  const cookieOk = await hasFounderDebugCookie();
  if (expected && cookieOk) {
    return { authorized: true };
  }

  const session = await getServerSession();
  if (session?.email && isFounderEmail(session.email)) {
    return { authorized: true };
  }

  return {
    authorized: false,
    response: NextResponse.json({ error: "Unauthorized" }, { status: 401 }),
  };
}
