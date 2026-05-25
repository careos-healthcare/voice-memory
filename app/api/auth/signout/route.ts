import { NextResponse } from "next/server";
import { cookies } from "next/headers";

import { SESSION_COOKIE } from "@/lib/server/auth-crypto";
import { clearSessionCookie, revokeServerSession } from "@/lib/server/session";

export const runtime = "nodejs";

export async function POST() {
  const cookieStore = await cookies();
  const token = cookieStore.get(SESSION_COOKIE)?.value;
  if (token) {
    await revokeServerSession(token);
  }

  const response = NextResponse.json({ ok: true });
  response.cookies.set(clearSessionCookie());
  return response;
}
