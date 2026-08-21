"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { RefreshCw } from "lucide-react";

import { ActivationBottleneckPanel } from "@/archived-components/_archived/internal/ActivationBottleneckPanel";
import { ActivationMetricsPanel } from "@/archived-components/_archived/internal/ActivationMetricsPanel";
import { InternalHubDecisionHeader } from "@/archived-components/_archived/internal/InternalHubDecisionHeader";
import { NorthStarDashboard } from "@/archived-components/_archived/internal/NorthStarDashboard";
import { OnboardingClarityDebugPanel } from "@/archived-components/_archived/debug/OnboardingClarityDebugPanel";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/archived-components/_archived/ui/button";
import { buildActivationBottleneckMetricsReport } from "@/lib/product/activation-bottleneck-metrics";
import { buildActivationMetricsReport } from "@/lib/product/activation-metrics";
import { buildOnboardingClarityDebugReport } from "@/lib/debug/onboarding-clarity";
import { buildNorthStarDashboard } from "@/lib/internal/north-star-report";
import type { OnboardingClarityDebugReport } from "@/types/onboarding-clarity";
import type { NorthStarDashboardView } from "@/types/founder-focus";

export default function InternalActivationPage() {
  const [activation, setActivation] = useState(() => buildActivationMetricsReport());
  const [bottleneck, setBottleneck] = useState(() => buildActivationBottleneckMetricsReport());
  const [onboarding, setOnboarding] = useState<OnboardingClarityDebugReport | null>(null);
  const [northStar, setNorthStar] = useState<NorthStarDashboardView | null>(null);

  const refresh = () => {
    setActivation(buildActivationMetricsReport());
    setBottleneck(buildActivationBottleneckMetricsReport());
    setOnboarding(buildOnboardingClarityDebugReport());
    const view = buildNorthStarDashboard();
    setNorthStar({
      ...view,
      metrics: view.metrics.filter((m) => m.id === "activation" || m.id === "curiosity"),
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
          route="/internal/activation"
          title="Activation"
          subheadline="Are people activating — first belief, discovery, and onboarding clarity."
          eyebrow="Activation"
        />
        <Button type="button" variant="ghost" size="sm" onClick={refresh}>
          <RefreshCw className="h-4 w-4" />
          Refresh
        </Button>
      </div>

      <div className="mt-8 space-y-10">
        <ActivationMetricsPanel report={activation} />
        <ActivationBottleneckPanel report={bottleneck} />
        {northStar ? <NorthStarDashboard initial={northStar} /> : null}
        {onboarding ? <OnboardingClarityDebugPanel report={onboarding} /> : null}
      </div>

      <p className="mt-10 text-sm">
        <Link href="/internal" className="text-violet-300 hover:text-violet-200">
          ← Command center
        </Link>
      </p>
    </div>
  );
}
