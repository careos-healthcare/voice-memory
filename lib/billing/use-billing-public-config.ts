"use client";

import { useEffect, useState } from "react";

import { PRO_PRICE_FALLBACK } from "@/lib/billing/billing-display-constants";

export interface BillingPublicConfigClient {
  billingLive: boolean;
  proPriceLabel: string;
  stripeCheckoutLine: string;
  loaded: boolean;
}

const DEFAULT: BillingPublicConfigClient = {
  billingLive: false,
  proPriceLabel: PRO_PRICE_FALLBACK,
  stripeCheckoutLine: "Stripe not configured in this environment",
  loaded: false,
};

export function useBillingPublicConfig(
  initial?: Partial<Omit<BillingPublicConfigClient, "loaded">>,
): BillingPublicConfigClient {
  const [config, setConfig] = useState<BillingPublicConfigClient>({
    ...DEFAULT,
    ...initial,
    proPriceLabel: initial?.proPriceLabel ?? DEFAULT.proPriceLabel,
    stripeCheckoutLine: initial?.stripeCheckoutLine ?? DEFAULT.stripeCheckoutLine,
    billingLive: initial?.billingLive ?? DEFAULT.billingLive,
    loaded: Boolean(initial?.billingLive !== undefined),
  });

  useEffect(() => {
    let cancelled = false;
    void fetch("/api/billing/config", { credentials: "same-origin" })
      .then((res) => (res.ok ? res.json() : null))
      .then((body) => {
        if (cancelled || !body) return;
        setConfig({
          billingLive: body.billingLive === true,
          proPriceLabel:
            typeof body.proPriceLabel === "string" ? body.proPriceLabel : PRO_PRICE_FALLBACK,
          stripeCheckoutLine:
            typeof body.stripeCheckoutLine === "string"
              ? body.stripeCheckoutLine
              : DEFAULT.stripeCheckoutLine,
          loaded: true,
        });
      })
      .catch(() => {
        if (!cancelled) setConfig((c) => ({ ...c, loaded: true }));
      });
    return () => {
      cancelled = true;
    };
  }, []);

  return config;
}
