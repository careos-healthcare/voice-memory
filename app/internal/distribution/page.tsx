"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { DistributionReportPanel } from "@/components/internal/DistributionReportPanel";
import { InternalHubDecisionHeader } from "@/components/internal/InternalHubDecisionHeader";
import { OrganicReferralPanel } from "@/components/internal/OrganicReferralPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { buildDistributionMetricRates } from "@/lib/distribution/distribution-metrics";
import { buildDistributionReport } from "@/lib/internal/distribution-report";
import { buildOrganicReferralReport } from "@/lib/internal/organic-referral-report";
import type { DistributionReport } from "@/types/distribution";

export default function InternalDistributionPage() {
  const [report, setReport] = useState<DistributionReport | null>(null);
  const [referral, setReferral] = useState(() => buildOrganicReferralReport());
  const metrics = buildDistributionMetricRates();

  const refresh = () => {
    setReport(buildDistributionReport());
    setReferral(buildOrganicReferralReport());
  };

  useEffect(() => {
    refresh();
  }, []);

  return (
    <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
      <SiteHeader />
      <div className="flex items-start justify-between gap-4">
        <InternalHubDecisionHeader
          route="/internal/distribution"
          title="Distribution"
          subheadline="Sharing, referrals, testimonials, and creator stories — merged distribution metrics."
          eyebrow="Distribution"
        />
        <Button type="button" variant="ghost" size="sm" onClick={refresh}>
          <RefreshCw className="h-4 w-4" />
          Refresh
        </Button>
      </div>

      <div className="mt-8 space-y-10">
        {report ? <DistributionReportPanel report={report} /> : null}
        <OrganicReferralPanel report={referral} />
        <section className="rounded-2xl border border-white/10 bg-zinc-900/40 px-4 py-4 text-sm text-zinc-400">
          <p className="text-xs uppercase tracking-wide text-zinc-600">Acquisition rates</p>
          <ul className="mt-2 space-y-1 font-mono text-xs">
            <li>Share rate: {metrics.shareRate ?? "—"}%</li>
            <li>Referral rate: {metrics.referralRate ?? "—"}%</li>
            <li>Testimonial rate: {metrics.testimonialRate ?? "—"}%</li>
            <li>Creator story rate: {metrics.creatorStoryRate ?? "—"}%</li>
          </ul>
        </section>
      </div>

      <div className="mt-10 flex flex-wrap gap-3 text-sm">
        <Link href="/creator-kit" className="text-violet-300 hover:text-violet-200">
          Creator kit →
        </Link>
        <Link href="/internal" className="text-zinc-500 hover:text-zinc-300">
          ← Command center
        </Link>
      </div>
    </div>
  );
}
