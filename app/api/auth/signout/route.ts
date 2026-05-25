import { NextResponse } from "next/server";
import { cookies } from "next/headers";

import { logAuthError } from "@/lib/server/auth-diagnostics";
import { SESSION_COOKIE } from "@/lib/server/auth-crypto";
import { clearSessionCookie, revokeServerSession } from "@/lib/server/session";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST() {
  try {
    const cookieStore = await cookies();
    const token = cookieStore.get(SESSION_COOKIE)?.value;
    if (token) {
      await revokeServerSession(token);
    }

    const response = NextResponse.json({ ok: true });
    response.cookies.set(clearSessionCookie());
    return response;
  } catch (error) {
    logAuthError("signout", error);
    const response = NextResponse.json({ ok: true });
    response.cookies.set(clearSessionCookie());
    return response;
  }
}
