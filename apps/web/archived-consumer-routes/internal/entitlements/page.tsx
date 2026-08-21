"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import {
  getPaymentStackAudit,
  isLiveBillingAvailable,
} from "@/lib/entitlement/payment-stack";
import {
  getTierSnapshot,
  listEntitlementRecords,
  setPreviewTier,
} from "@/lib/entitlement/entitlements";
import { FREE_TIER, PRO_TIER } from "@/lib/entitlement/tiers";
import type { TierSnapshot } from "@/types/entitlement";

export default function EntitlementsDebugPage() {
  const [snapshot, setSnapshot] = useState<TierSnapshot | null>(null);
  const audit = getPaymentStackAudit();

  const refresh = () => {
    setSnapshot(getTierSnapshot());
  };

  useEffect(() => {
    refresh();
  }, []);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Debug only</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Entitlements & billing audit
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Payment stack status, tier matrix, and per-feature gates. Not shown in the product UI.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={refresh}>
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
        </header>

        <Card className="mt-8 border-white/10 bg-zinc-900/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-base text-zinc-200">Payment stack</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-zinc-400">
            <p>{audit.summary}</p>
            <ul className="list-inside list-disc text-xs text-zinc-500">
              <li>Stripe SDK: {audit.stripeSdkPresent ? "yes" : "no"}</li>
              <li>Stripe checkout route: {audit.stripeCheckoutRoute ? "yes" : "no"}</li>
              <li>RevenueCat: {audit.revenueCatPresent ? "yes" : "no"}</li>
              <li>Live checkout: {isLiveBillingAvailable() ? "yes" : "no"}</li>
            </ul>
          </CardContent>
        </Card>

        {snapshot ? (
          <>
            <Card className="mt-4 border-white/10 bg-zinc-900/50">
              <CardHeader className="pb-2">
                <CardTitle className="text-base text-zinc-200">Current snapshot</CardTitle>
              </CardHeader>
              <CardContent className="space-y-2 text-sm text-zinc-400">
                <p>
                  Tier: <span className="text-zinc-200">{snapshot.tier}</span>
                  {snapshot.previewMode ? " (local preview)" : ""}
                </p>
                <p className="text-xs text-zinc-600">
                  Billing connected: {snapshot.billingConnected ? "yes" : "no"}
                </p>
                <div className="flex flex-wrap gap-2 pt-2">
                  <Button
                    type="button"
                    size="sm"
                    variant="secondary"
                    onClick={() => {
                      setPreviewTier("free");
                      refresh();
                    }}
                  >
                    Preview Free
                  </Button>
                  <Button
                    type="button"
                    size="sm"
                    variant="secondary"
                    onClick={() => {
                      setPreviewTier("pro");
                      refresh();
                    }}
                  >
                    Preview Pro
                  </Button>
                </div>
              </CardContent>
            </Card>

            <Card className="mt-4 border-white/10 bg-zinc-900/50">
              <CardHeader className="pb-2">
                <CardTitle className="text-base text-zinc-200">Entitlements</CardTitle>
              </CardHeader>
              <CardContent className="space-y-1 text-sm">
                {listEntitlementRecords().map((row) => (
                  <p
                    key={row.id}
                    className={row.granted ? "text-emerald-400/90" : "text-zinc-600"}
                  >
                    {row.granted ? "✓" : "·"} {row.id}
                  </p>
                ))}
              </CardContent>
            </Card>

            <div className="mt-6 grid gap-4 sm:grid-cols-2">
              {[FREE_TIER, PRO_TIER].map((tier) => (
                <Card key={tier.id} className="border-white/10 bg-zinc-900/30">
                  <CardHeader className="pb-2">
                    <CardTitle className="text-sm text-zinc-300">{tier.label}</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <ul className="space-y-1 text-xs text-zinc-500">
                      {tier.featureBullets.map((line) => (
                        <li key={line}>{line}</li>
                      ))}
                    </ul>
                  </CardContent>
                </Card>
              ))}
            </div>
          </>
        ) : null}

        <p className="mt-8 text-sm">
          <Link href="/pricing" className="text-violet-300 hover:text-zinc-200">
            Pricing page →
          </Link>
          {" · "}
          <Link href="/internal/monetization-readiness" className="text-zinc-500 hover:text-zinc-300">
            Monetization readiness →
          </Link>
        </p>
      </div>
    </div>
  );
}
