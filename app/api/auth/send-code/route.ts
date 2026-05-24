import { NextResponse } from "next/server";

import { issueEmailLoginCode } from "@/lib/server/auth-store";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    const body = (await request.json()) as { email?: string };
    const email = body.email?.trim();
    if (!email) {
      return NextResponse.json({ error: "Email is required." }, { status: 400 });
    }

    const { code } = issueEmailLoginCode(email);

    // Foundation: log code in development. Wire SMTP in production deployment.
    if (process.env.NODE_ENV !== "production") {
      console.info(`[VoiceMemory auth] Sign-in code for ${email}: ${code}`);
    }

    const response: { ok: true; devCode?: string } = { ok: true };
    if (process.env.NODE_ENV !== "production") {
      response.devCode = code;
    }

    return NextResponse.json(response);
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Could not send code." },
      { status: 400 },
    );
  }
}
