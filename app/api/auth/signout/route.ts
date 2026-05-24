import { NextResponse } from "next/server";

import { clearSessionCookie } from "@/lib/server/session";

export const runtime = "nodejs";

export async function POST() {
  const response = NextResponse.json({ ok: true });
  response.cookies.set(clearSessionCookie());
  return response;
}
