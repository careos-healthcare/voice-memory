"use client";

import { useEffect, useState } from "react";
import { RefreshCw } from "lucide-react";

import { EvolvingUnderstandingPanel } from "@/archived-components/_archived/internal/EvolvingUnderstandingPanel";
import { ActivationBottleneckPanel } from "@/archived-components/_archived/internal/ActivationBottleneckPanel";
import { ArchiveValueProgressPanel } from "@/archived-components/_archived/internal/ArchiveValueProgressPanel";
import { ValueMomentPaywallPanel } from "@/archived-components/_archived/internal/ValueMomentPaywallPanel";
import { ActivationMetricsPanel } from "@/archived-components/_archived/internal/ActivationMetricsPanel";
import { RetentionDiscoveryPanel } from "@/archived-components/_archived/internal/RetentionDiscoveryPanel";
import { ArchiveAttachmentPanel } from "@/archived-components/_archived/internal/ArchiveAttachmentPanel";
import { BeliefRecallPanel } from "@/archived-components/_archived/internal/BeliefRecallPanel";
import { OrganicReferralPanel } from "@/archived-components/_archived/internal/OrganicReferralPanel";
import { PaywallAttributionPanel } from "@/archived-components/_archived/internal/PaywallAttributionPanel";
import { buildArchiveAttachmentReport } from "@/lib/internal/archive-attachment-report";
import { buildBeliefRecallReport } from "@/lib/internal/belief-recall-report";
import { buildOrganicReferralReport } from "@/lib/internal/organic-referral-report";
import { ReturnTriggerPanel } from "@/archived-components/_archived/internal/ReturnTriggerPanel";
import { buildPaywallAttributionReport } from "@/lib/internal/paywall-attribution-report";
import { RetentionMoatPanel } from "@/archived-components/_archived/internal/RetentionMoatPanel";
import { buildReturnTriggerAttributionReport } from "@/lib/internal/return-trigger-attribution-report";
import { buildRetentionMoatReport } from "@/lib/internal/retention-moat-report";
import { buildValueMomentPaywallMetricsReport } from "@/lib/billing/value-moment-paywall-metrics";
import { buildArchiveValueMetricsReport } from "@/lib/product/archive-value-metrics";
import { buildActivationBottleneckMetricsReport } from "@/lib/product/activation-bottleneck-metrics";
import { buildActivationMetricsReport } from "@/lib/product/activation-metrics";
import type { ActivationBottleneckMetricsReport } from "@/lib/product/activation-bottleneck-metrics";
import type { ActivationMetricsReport } from "@/lib/product/activation-metrics";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent } from "@/archived-components/_archived/ui/card";
import { buildEvolvingUnderstandingReport } from "@/lib/metrics/evolving-understanding-report";
import { buildRetentionDiscoveryReport } from "@/lib/retention/retention-discovery-report";
import type { RetentionDiscoveryReport } from "@/types/retention-discovery";

export default function RetentionDiscoveryPage() {
  const [report, setReport] = useState<RetentionDiscoveryReport | null>(null);
  const [activationReport, setActivationReport] = useState<ActivationMetricsReport | null>(
    null,
  );
  const [bottleneckReport, setBottleneckReport] = useState<ActivationBottleneckMetricsReport | null>(
    null,
  );
  const [archiveValueReport, setArchiveValueReport] = useState(
    () => buildArchiveValueMetricsReport(),
  );
  const [valueMomentPaywallReport, setValueMomentPaywallReport] = useState(
    () => buildValueMomentPaywallMetricsReport(),
  );
  const [evolvingReport, setEvolvingReport] = useState(() =>
    buildEvolvingUnderstandingReport(),
  );
  const [moatReport, setMoatReport] = useState(() => buildRetentionMoatReport());
  const [returnTriggerReport, setReturnTriggerReport] = useState(() =>
    buildReturnTriggerAttributionReport(),
  );
  const [paywallAttributionReport, setPaywallAttributionReport] = useState(() =>
    buildPaywallAttributionReport(),
  );
  const [archiveAttachmentReport, setArchiveAttachmentReport] = useState(() =>
    buildArchiveAttachmentReport(),
  );
  const [organicReferralReport, setOrganicReferralReport] = useState(() =>
    buildOrganicReferralReport(),
  );
  const [beliefRecallReport, setBeliefRecallReport] = useState(() => buildBeliefRecallReport());

  const refresh = () => {
    setReport(buildRetentionDiscoveryReport());
    setActivationReport(buildActivationMetricsReport());
    setBottleneckReport(buildActivationBottleneckMetricsReport());
    setArchiveValueReport(buildArchiveValueMetricsReport());
    setValueMomentPaywallReport(buildValueMomentPaywallMetricsReport());
    setEvolvingReport(buildEvolvingUnderstandingReport());
    setMoatReport(buildRetentionMoatReport());
    setReturnTriggerReport(buildReturnTriggerAttributionReport());
    setPaywallAttributionReport(buildPaywallAttributionReport());
    setArchiveAttachmentReport(buildArchiveAttachmentReport());
    setOrganicReferralReport(buildOrganicReferralReport());
    setBeliefRecallReport(buildBeliefRecallReport());
  };

  useEffect(() => {
    refresh();
  }, []);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2 flex items-start justify-between gap-4">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Retention</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
              Retention discovery
            </h1>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
              Why users return — return reasons, first value timing, session outcomes, and signal
              correlations. Measurement only; no coaching or recommendations.
            </p>
          </div>
          <Button type="button" variant="ghost" size="sm" onClick={refresh}>
            <RefreshCw className="h-4 w-4" />
            Refresh
          </Button>
        </header>

        {!report ? (
          <Card className="mt-6">
            <CardContent className="py-12 text-center text-sm text-zinc-500">Loading…</CardContent>
          </Card>
        ) : (
          <div className="mt-6 space-y-10">
            <BeliefRecallPanel report={beliefRecallReport} />
            <OrganicReferralPanel report={organicReferralReport} />
            <ArchiveAttachmentPanel report={archiveAttachmentReport} />
            <PaywallAttributionPanel report={paywallAttributionReport} />
            <ReturnTriggerPanel report={returnTriggerReport} />
            <RetentionMoatPanel report={moatReport} />
            <EvolvingUnderstandingPanel report={evolvingReport} />
            {activationReport ? <ActivationMetricsPanel report={activationReport} /> : null}
            <ArchiveValueProgressPanel report={archiveValueReport} />
            <ValueMomentPaywallPanel report={valueMomentPaywallReport} />
            {bottleneckReport ? (
              <ActivationBottleneckPanel report={bottleneckReport} />
            ) : null}
            <RetentionDiscoveryPanel report={report} />
          </div>
        )}

      </div>
    </div>
  );
}
