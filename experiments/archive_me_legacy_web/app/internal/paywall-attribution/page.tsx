"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { PaywallAttributionPanel } from "@/components/internal/PaywallAttributionPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { buildPaywallAttributionReport } from "@/lib/internal/paywall-attribution-report";
import type { PaywallAttributionReport } from "@/types/paywall-attribution";

export default function PaywallAttributionPage() {
  const [report, setReport] = useState<PaywallAttributionReport | null>(null);

  const refresh = () => setReport(buildPaywallAttributionReport());

  useEffect(() => {
    refresh();
  }, []);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Billing</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Paywall attribution
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              What made Pro interesting, what blocked upgrade, and what convinced subscribers —
              correlated with retention and breakthrough on this device.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={refresh}>
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
        </header>

        <div className="mt-6">{report ? <PaywallAttributionPanel report={report} /> : null}</div>

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/internal/retention-discovery" className="text-violet-300 hover:text-violet-200">
            Retention discovery →
          </Link>
        </div>
      </div>
    </div>
  );
}
