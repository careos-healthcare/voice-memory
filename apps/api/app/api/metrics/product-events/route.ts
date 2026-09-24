import { NextResponse } from "next/server";

import { recordAggregateProductEvent } from "@/lib/server/product-event-counts";

export const runtime = "nodejs";

const eventNamePattern = /^[a-z][a-z0-9_]{0,39}$/;
const hits = new Map<string, { count: number; resetAt: number }>();

function allow(ip: string): boolean {
  const now = Date.now();
  const current = hits.get(ip);
  if (!current || current.resetAt <= now) {
    hits.set(ip, { count: 1, resetAt: now + 60 * 60 * 1000 });
    return true;
  }
  if (current.count >= 120) return false;
  current.count += 1;
  return true;
}

function clientIp(request: Request): string {
  const forwarded = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim();
  return forwarded || "unknown";
}

/** Accepts an event name only. Parameters, ids, and content are discarded. */
export async function POST(request: Request) {
  if (!allow(clientIp(request))) {
    return NextResponse.json({ error: "limited" }, { status: 429 });
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "invalid" }, { status: 400 });
  }

  const event =
    body && typeof body === "object" && "event" in body
      ? (body as { event?: unknown }).event
      : undefined;
  if (typeof event !== "string" || !eventNamePattern.test(event)) {
    return NextResponse.json({ error: "invalid" }, { status: 400 });
  }

  await recordAggregateProductEvent(event);
  return NextResponse.json({ ok: true });
}
