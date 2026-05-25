import { NextResponse } from "next/server";

import {
  AuthEmailDeliveryError,
  AuthEmailNotConfiguredError,
  sendAuthCodeEmail,
} from "@/lib/email/send-auth-code";
import { AuthStorageNotConfiguredError, issueEmailLoginCode } from "@/lib/server/auth-store";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    const body = (await request.json()) as { email?: string };
    const email = body.email?.trim();
    if (!email) {
      return NextResponse.json({ error: "Email is required." }, { status: 400 });
    }

    const { code } = issueEmailLoginCode(email);

    if (process.env.NODE_ENV !== "production") {
      console.info(`[VoiceMemory auth] Sign-in code for ${email}: ${code}`);
    } else {
      await sendAuthCodeEmail(email, code);
    }

    const response: { ok: true; message: string; devCode?: string } = {
      ok: true,
      message: "Code sent. Check your email.",
    };
    if (process.env.NODE_ENV !== "production") {
      response.devCode = code;
    }

    return NextResponse.json(response);
  } catch (error) {
    if (error instanceof AuthStorageNotConfiguredError) {
      return NextResponse.json(
        { error: error.message, code: "storage_not_configured" },
        { status: 503 },
      );
    }

    if (error instanceof AuthEmailNotConfiguredError) {
      console.error("[VoiceMemory auth] Email provider not configured:", error.message);
      return NextResponse.json(
        { error: error.message, code: "email_not_configured" },
        { status: 503 },
      );
    }

    if (error instanceof AuthEmailDeliveryError) {
      return NextResponse.json(
        { error: error.message, code: "email_delivery_failed" },
        { status: 502 },
      );
    }

    return NextResponse.json(
      {
        error: error instanceof Error ? error.message : "Could not send code. Try again.",
      },
      { status: 400 },
    );
  }
}
