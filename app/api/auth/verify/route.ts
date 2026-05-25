import { NextResponse } from "next/server";

import { verifyEmailLoginCode } from "@/lib/server/auth-store";
import {
  buildSessionCookie,
  createSessionTokenForUser,
  persistSessionForUser,
} from "@/lib/server/session";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    const body = (await request.json()) as { email?: string; code?: string };
    const email = body.email?.trim();
    const code = body.code?.trim();
    if (!email || !code) {
      return NextResponse.json({ error: "Email and code are required." }, { status: 400 });
    }

    const user = await verifyEmailLoginCode(email, code);
    if (!user) {
      return NextResponse.json({ error: "Invalid or expired code." }, { status: 401 });
    }

    const token = createSessionTokenForUser(user);
    await persistSessionForUser(token, user);
    const response = NextResponse.json({
      session: {
        user: { id: user.id, email: user.email },
        signedInAt: new Date().toISOString(),
      },
    });
    response.cookies.set(buildSessionCookie(token));
    return response;
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Sign-in failed." },
      { status: 400 },
    );
  }
}
