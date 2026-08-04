"use client";

import { useEffect, useRef } from "react";

import { WEB_STRIPE_FUNNEL_EVENTS } from "@/lib/analytics/web-stripe-funnel-events";

export function LandingPageAnalytics() {
  const sent = useRef(false);

  useEffect(() => {
    if (sent.current) return;
    sent.current = true;
    void fetch("/api/analytics/funnel", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        event: WEB_STRIPE_FUNNEL_EVENTS.landingPageView,
      }),
      keepalive: true,
    }).catch(() => {
      // Analytics is best-effort and must never interrupt the landing page.
    });
  }, []);

  return null;
}
