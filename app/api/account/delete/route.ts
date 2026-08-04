import { NextResponse } from "next/server";

import {
  deleteUserServerData,
} from "@/lib/server/account-deletion";
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

  const result = await deleteUserServerData(session.userId, session.email);

  const response = NextResponse.json({
    ok: true,
    pending: result.pending,
    ...(result.receiptId ? { receiptId: result.receiptId } : {}),
    message: result.pending
      ? "Account deletion is in progress. Provider deletion will continue automatically."
      : "Server account data removed. Clear local data on this device from Settings if you have not already.",
  }, { status: result.pending ? 202 : 200 });
  response.cookies.set(clearSessionCookie());

  return response;
}
