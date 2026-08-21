"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { InternalHubDecisionHeader } from "@/archived-components/_archived/internal/InternalHubDecisionHeader";
import { PaywallAttributionPanel } from "@/archived-components/_archived/internal/PaywallAttributionPanel";
import { ValueMomentPaywallPanel } from "@/archived-components/_archived/internal/ValueMomentPaywallPanel";
import { NorthStarDashboard } from "@/archived-components/_archived/internal/NorthStarDashboard";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import { buildPaywallAttributionReport } from "@/lib/internal/paywall-attribution-report";
import { buildNorthStarDashboard } from "@/lib/internal/north-star-report";
import { buildValueMomentPaywallMetricsReport } from "@/lib/billing/value-moment-paywall-metrics";
import { getTierSnapshot } from "@/lib/entitlement/entitlements";
import {
  getPaymentStackAudit,
  isLiveBillingAvailable,
} from "@/lib/entitlement/payment-stack";
import { FREE_TIER, PRO_TIER } from "@/lib/entitlement/tiers";
import type { NorthStarDashboardView } from "@/types/founder-focus";

export default function InternalConversionPage() {
  const [paywall, setPaywall] = useState(() => buildPaywallAttributionReport());
  const [valueMoment, setValueMoment] = useState(() => buildValueMomentPaywallMetricsReport());
  const [northStar, setNorthStar] = useState<NorthStarDashboardView | null>(null);
  const audit = getPaymentStackAudit();
  const tier = getTierSnapshot();

  const refresh = () => {
    setPaywall(buildPaywallAttributionReport());
    setValueMoment(buildValueMomentPaywallMetricsReport());
    const view = buildNorthStarDashboard();
    setNorthStar({
      ...view,
      metrics: view.metrics.filter((m) => m.id === "conversion" || m.id === "attachment"),
    });
  };

  useEffect(() => {
    refresh();
  }, []);

  return (
    <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
      <SiteHeader />
      <div className="flex items-start justify-between gap-4">
        <InternalHubDecisionHeader
          route="/internal/conversion"
          title="Conversion"
          subheadline="Paywall attribution, value-moment paywall, and subscription stack — merged conversion view."
          eyebrow="Conversion"
        />
        <Button type="button" variant="ghost" size="sm" onClick={refresh}>
          <RefreshCw className="h-4 w-4" />
          Refresh
        </Button>
      </div>

      <div className="mt-8 space-y-10">
        <Card className="border-white/10 bg-zinc-900/50">
          <CardHeader>
            <CardTitle className="text-lg text-zinc-200">Subscription</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-zinc-400">
            <p>
              Tier: <span className="text-zinc-200">{tier.tier}</span> · Live billing:{" "}
              {isLiveBillingAvailable() ? "yes" : "no"}
            </p>
            <p>
              {FREE_TIER.label} → {PRO_TIER.label} ({PRO_TIER.priceLabel})
            </p>
            <p className="text-xs text-zinc-600">{audit.summary}</p>
          </CardContent>
        </Card>
        <PaywallAttributionPanel report={paywall} />
        <ValueMomentPaywallPanel report={valueMoment} />
        {northStar ? <NorthStarDashboard initial={northStar} /> : null}
      </div>

      <p className="mt-10 text-sm">
        <Link href="/internal" className="text-violet-300 hover:text-violet-200">
          ← Command center
        </Link>
      </p>
    </div>
  );
}
