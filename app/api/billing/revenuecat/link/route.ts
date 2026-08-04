import { NextResponse } from "next/server";

import {
  normalizeRevenueCatAppUserId,
  upsertRevenueCatUserMapping,
} from "@/lib/server/revenuecat-mapping";
import { getServerSession } from "@/lib/server/session";

export const runtime = "nodejs";

export async function POST(request: Request) {
  const session = await getServerSession();
  if (!session) {
    return NextResponse.json(
      { error: "Sign in required.", code: "AUTH_REQUIRED" },
      { status: 401 },
    );
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { error: "Invalid JSON body.", code: "INVALID_REQUEST" },
      { status: 400 },
    );
  }
  const appUserId = normalizeRevenueCatAppUserId(
    (body as { appUserId?: unknown } | null)?.appUserId,
  );
  if (!appUserId) {
    return NextResponse.json(
      { error: "A valid RevenueCat appUserId is required.", code: "INVALID_APP_USER_ID" },
      { status: 400 },
    );
  }
  if (appUserId !== session.userId.toLowerCase()) {
    return NextResponse.json(
      {
        error: "RevenueCat identity does not match the signed-in account.",
        code: "REVENUECAT_IDENTITY_MISMATCH",
      },
      { status: 403 },
    );
  }

  try {
    await upsertRevenueCatUserMapping(session.userId, appUserId);
    return NextResponse.json({ linked: true });
  } catch (error) {
    const code =
      typeof error === "object" && error !== null && "code" in error
        ? String(error.code)
        : "";
    if (
      code === "23505" ||
      (error instanceof Error &&
        error.message === "revenuecat_app_user_id_in_use")
    ) {
      return NextResponse.json(
        {
          error: "This RevenueCat identity is already linked.",
          code: "REVENUECAT_APP_USER_ID_IN_USE",
        },
        { status: 409 },
      );
    }
    throw error;
  }
}
