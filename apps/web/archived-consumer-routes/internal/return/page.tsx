"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { ArchiveAttachmentPanel } from "@/archived-components/_archived/internal/ArchiveAttachmentPanel";
import { BeliefRecallPanel } from "@/archived-components/_archived/internal/BeliefRecallPanel";
import { InternalHubDecisionHeader } from "@/archived-components/_archived/internal/InternalHubDecisionHeader";
import { OrganicReferralPanel } from "@/archived-components/_archived/internal/OrganicReferralPanel";
import { PaywallAttributionPanel } from "@/archived-components/_archived/internal/PaywallAttributionPanel";
import { ReturnTriggerPanel } from "@/archived-components/_archived/internal/ReturnTriggerPanel";
import { RetentionDiscoveryPanel } from "@/archived-components/_archived/internal/RetentionDiscoveryPanel";
import { RetentionMoatPanel } from "@/archived-components/_archived/internal/RetentionMoatPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/archived-components/_archived/ui/button";
import { buildArchiveAttachmentReport } from "@/lib/internal/archive-attachment-report";
import { buildBeliefRecallReport } from "@/lib/internal/belief-recall-report";
import { buildOrganicReferralReport } from "@/lib/internal/organic-referral-report";
import { buildPaywallAttributionReport } from "@/lib/internal/paywall-attribution-report";
import { buildReturnTriggerAttributionReport } from "@/lib/internal/return-trigger-attribution-report";
import { buildRetentionMoatReport } from "@/lib/internal/retention-moat-report";
import { buildRetentionDiscoveryReport } from "@/lib/retention/retention-discovery-report";
import type { RetentionDiscoveryReport } from "@/types/retention-discovery";

export default function InternalReturnPage() {
  const [discovery, setDiscovery] = useState<RetentionDiscoveryReport | null>(null);
  const [returnTrigger, setReturnTrigger] = useState(() => buildReturnTriggerAttributionReport());
  const [attachment, setAttachment] = useState(() => buildArchiveAttachmentReport());
  const [referral, setReferral] = useState(() => buildOrganicReferralReport());
  const [beliefRecall, setBeliefRecall] = useState(() => buildBeliefRecallReport());
  const [moat, setMoat] = useState(() => buildRetentionMoatReport());
  const [paywall, setPaywall] = useState(() => buildPaywallAttributionReport());

  const refresh = () => {
    setDiscovery(buildRetentionDiscoveryReport());
    setReturnTrigger(buildReturnTriggerAttributionReport());
    setAttachment(buildArchiveAttachmentReport());
    setReferral(buildOrganicReferralReport());
    setBeliefRecall(buildBeliefRecallReport());
    setMoat(buildRetentionMoatReport());
    setPaywall(buildPaywallAttributionReport());
  };

  useEffect(() => {
    refresh();
  }, []);

  return (
    <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
      <SiteHeader />
      <div className="flex items-start justify-between gap-4">
        <InternalHubDecisionHeader
          route="/internal/return"
          title="Return"
          subheadline="Attachment, belief recall, return triggers, organic referral — merged return loop."
          eyebrow="Return"
        />
        <Button type="button" variant="ghost" size="sm" onClick={refresh}>
          <RefreshCw className="h-4 w-4" />
          Refresh
        </Button>
      </div>

      <div className="mt-8 space-y-10">
        {discovery ? <RetentionDiscoveryPanel report={discovery} /> : null}
        <ReturnTriggerPanel report={returnTrigger} />
        <ArchiveAttachmentPanel report={attachment} />
        <BeliefRecallPanel report={beliefRecall} />
        <OrganicReferralPanel report={referral} />
        <RetentionMoatPanel report={moat} />
        <PaywallAttributionPanel report={paywall} />
      </div>

      <p className="mt-10 text-sm">
        <Link href="/internal" className="text-violet-300 hover:text-violet-200">
          ← Command center
        </Link>
      </p>
    </div>
  );
}
