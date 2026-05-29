import { NextResponse } from "next/server";
import { cookies } from "next/headers";

import {
  deleteUserServerData,
  revokeAllSessionsForUser,
} from "@/lib/server/account-deletion";
import { SESSION_COOKIE } from "@/lib/server/auth-crypto";
import {
  clearSessionCookie,
  getServerSession,
} from "@/lib/server/session";

export const runtime = "nodejs";

export async function POST(request: Request) {
  const session = await getServerSession();
  if (!session) {
    return NextResponse.json(
      { error: "Sign in required to delete server account data.", code: "AUTH_REQUIRED" },
      { status: 401 },
    );
  }

  let confirm = false;
  try {
    const body = (await request.json()) as { confirm?: boolean };
    confirm = body.confirm === true;
  } catch {
    confirm = false;
  }

  if (!confirm) {
    return NextResponse.json(
      { error: "Confirmation required.", code: "CONFIRM_REQUIRED" },
      { status: 400 },
    );
  }

  const cookieStore = await cookies();
  const token = cookieStore.get(SESSION_COOKIE)?.value ?? "";

  const removed = await deleteUserServerData(session.userId, session.email);
  await revokeAllSessionsForUser(session.userId, token);

  const response = NextResponse.json({
    ok: true,
    removed,
    message:
      "Server account data removed. Clear local data on this device from Settings if you have not already.",
  });
  response.cookies.set(clearSessionCookie());

  return response;
}
