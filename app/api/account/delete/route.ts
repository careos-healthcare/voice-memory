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

  const result = await deleteUserServerData(session.userId, session.email);

  // Session revocation must never prevent the session cookie from being
  // cleared below — a throw here is reported honestly instead of aborting
  // the response before the cookie clear runs.
  let sessionRevokeError: string | null = null;
  try {
    await revokeAllSessionsForUser(session.userId, token);
  } catch (error) {
    sessionRevokeError = error instanceof Error ? error.message : "Session revocation failed.";
  }

  const ok = result.ok && !sessionRevokeError;
  const response = NextResponse.json({
    ok,
    stores: result.stores,
    sessionRevokeError,
    error: ok
      ? undefined
      : "Server account data deletion was only partially completed. Some data may remain — contact support if this persists.",
    message: ok
      ? "Server account data removed. Clear local data on this device from Settings if you have not already."
      : "Server account data deletion was only partially completed. Some data may remain — contact support if this persists.",
  });
  // Cleared unconditionally, regardless of any deletion/revocation failure above —
  // a partial server-side failure must never leave the client believing it still
  // has a valid, authenticated session.
  response.cookies.set(clearSessionCookie());

  return response;
}
