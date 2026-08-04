import { NextResponse } from "next/server";

import { WEB_STRIPE_FUNNEL_EVENTS } from "@/lib/analytics/web-stripe-funnel-events";
import { trackWebStripeFunnelEvent } from "@/lib/server/analytics-service";

export const runtime = "nodejs";

export async function POST(request: Request) {
  const body = await request.json().catch(() => null);
  if (
    !body ||
    typeof body !== "object" ||
    !("event" in body) ||
    body.event !== WEB_STRIPE_FUNNEL_EVENTS.landingPageView
  ) {
    return NextResponse.json(
      { error: "Unsupported analytics event.", code: "INVALID_EVENT" },
      { status: 400 },
    );
  }

  trackWebStripeFunnelEvent(WEB_STRIPE_FUNNEL_EVENTS.landingPageView, {
    source: "web_landing",
  });
  return NextResponse.json({ accepted: true }, { status: 202 });
}
