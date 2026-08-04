"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { AnimatedReveal } from "@/components/motion/AnimatedReveal";
import { Check, Crown, Lock } from "lucide-react";

import { ArchiveDifferenceCard } from "@/components/archive/ArchiveDifferenceCard";
import { ArchiveUniquenessPanel } from "@/components/archive/ArchiveUniquenessPanel";
import { ArchiveAssetCard } from "@/components/archive/ArchiveAssetCard";
import { ArchiveVisualModel } from "@/components/archive/ArchiveVisualModel";
import { WhyPeopleReturn } from "@/components/archive/WhyPeopleReturn";
import { ArchiveWorthStatement } from "@/components/archive/ArchiveWorthStatement";
import { ArchiveProgressBar } from "@/components/archive/ArchiveProgressBar";
import { EffortCompoundsPanel } from "@/components/archive/EffortCompoundsPanel";
import { WhatThisArchiveCanAnswer } from "@/components/archive/WhatThisArchiveCanAnswer";
import { ArchiveProofStories } from "@/components/social-proof/ArchiveProofStories";
import { ConversionReasonPrompt } from "@/components/billing/ConversionReasonPrompt";
import { PrivacyNotice } from "@/components/system";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { getTierSnapshot } from "@/lib/entitlement/entitlements";
import { isProPreviewAllowed } from "@/lib/billing/billing-state";
import { VALUE_MOMENT_PRICING_COPY } from "@/lib/billing/value-moment-paywall-copy";
import {
  getPlanId,
  getUpgradeClickEvents,
  isProUser,
  PRO_MEMORY_FEATURES,
  setPlanId,
  trackUpgradeClick,
  type PlanId,
  type UpgradeClickSource,
} from "@/lib/subscription";
import { PRO_DESCRIPTION, PRO_HEADLINE } from "@/lib/product/pro-framing";
import { LANDING_3_DAY_CHALLENGE } from "@/lib/product/landing-three-day-challenge-copy";
import { HONESTY_LINE, NOT_AI_JOURNAL_LINE } from "@/lib/product-copy";
import { trackPilotPricingOpened } from "@/lib/pilot/pilot-interest";
import { RETENTION_EVENTS, trackRetentionEvent } from "@/lib/local-analytics";

function PlanFeature({ children }: { children: React.ReactNode }) {
  return (
    <li className="flex items-start gap-2 text-sm text-zinc-300">
      <Check className="mt-0.5 h-4 w-4 shrink-0 text-emerald-400" />
      <span>{children}</span>
    </li>
  );
}

export function PricingPageClient() {
  const searchParams = useSearchParams();
  const from = (searchParams.get("from") ?? "pricing") as UpgradeClickSource;

  const [plan, setPlan] = useState<PlanId>("free");
  const [clickCount, setClickCount] = useState(0);
  const [showCheckoutNotice, setShowCheckoutNotice] = useState(false);
  const proPriceLabel = "Store price shown in the ArchiveMe mobile app";
  const storeLine =
    "Monthly and annual subscriptions are sold through the app stores.";
  const tierSnapshot = getTierSnapshot();
  const paidPro = tierSnapshot.tier === "pro" && !tierSnapshot.previewMode;
  const previewPro = tierSnapshot.previewMode && tierSnapshot.tier === "pro";

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      setPlan(getPlanId());
      setClickCount(getUpgradeClickEvents().length);
      trackRetentionEvent(RETENTION_EVENTS.pricingViewed, { from });
      if (from === "pilot") trackPilotPricingOpened();
    });
    return () => cancelAnimationFrame(id);
  }, [from]);

  const handleUpgrade = () => {
    trackUpgradeClick(from, "pricing_cta");
    setClickCount(getUpgradeClickEvents().length);
    setShowCheckoutNotice(true);
  };

  const togglePreviewPro = () => {
    const next: PlanId = isProUser() ? "free" : "pro";
    setPlanId(next);
    setPlan(next);
  };

  return (
    <>
      <ConversionReasonPrompt className="mt-4" source={from} refreshKey={0} />
      <AnimatedReveal className="mt-4 text-center sm:text-left">
        <p className="text-sm leading-relaxed text-zinc-300">
          {VALUE_MOMENT_PRICING_COPY.pageLead}
        </p>
        <p className="mt-2 text-sm leading-relaxed text-zinc-400">
          {LANDING_3_DAY_CHALLENGE.chatGptDifferentiation}
        </p>
        <ArchiveVisualModel compact className="mt-4" />
        <ArchiveDifferenceCard className="mt-4" />
        <ArchiveUniquenessPanel className="mt-4" />
        <WhyPeopleReturn className="mt-4" />
        <p className="mt-4 text-sm leading-relaxed text-violet-200/90">
          {VALUE_MOMENT_PRICING_COPY.proReason}
        </p>
        <ArchiveProgressBar
          surface="pricing"
          className="mt-4 text-left"
          linkHref="/discover"
        />
        <WhatThisArchiveCanAnswer className="mt-4 text-left" />
        <ArchiveAssetCard surface="pricing" className="mt-4 text-left" />
        <ArchiveWorthStatement compact className="mt-4 text-left" />
        <EffortCompoundsPanel className="mt-4 text-left" />
        <ArchiveProofStories className="mt-4 text-left" />
        <p className="mt-4 text-sm leading-relaxed text-zinc-300">
          Free stays local-first on your device. {PRO_DESCRIPTION}
        </p>
        <p className="mt-2 text-xs text-muted">{NOT_AI_JOURNAL_LINE}</p>
        <p className="mt-1 text-xs text-muted">{HONESTY_LINE}</p>
        {paidPro ? (
          <p className="mt-2 text-xs text-emerald-200">
            Paid Pro (server entitlements)
          </p>
        ) : null}
        {previewPro ? (
          <p className="mt-2 text-xs text-violet-200">
            Pro preview (local only)
          </p>
        ) : null}
      </AnimatedReveal>

      <div className="mt-6 grid gap-4 sm:grid-cols-2">
        <Card className="border-white/10">
          <CardHeader>
            <CardTitle className="text-lg">Free</CardTitle>
            <p className="text-2xl font-semibold text-white">Free</p>
          </CardHeader>
          <CardContent>
            <ul className="space-y-2.5">
              {VALUE_MOMENT_PRICING_COPY.freeFeatures.map((item) => (
                <PlanFeature key={item}>{item}</PlanFeature>
              ))}
            </ul>
            {plan === "free" ? (
              <p className="mt-4 text-xs text-violet-200">Current plan</p>
            ) : (
              <Button
                type="button"
                variant="secondary"
                size="sm"
                className="mobile-touch-target mt-4"
                onClick={() => {
                  setPlanId("free");
                  setPlan("free");
                }}
              >
                Use Free
              </Button>
            )}
          </CardContent>
        </Card>

        <Card className="border-violet-400/30 bg-gradient-to-br from-violet-500/15 via-transparent to-fuchsia-500/10">
          <CardHeader>
            <div className="flex items-center gap-2">
              <Crown className="h-5 w-5 text-violet-200" />
              <CardTitle className="text-lg">Pro</CardTitle>
            </div>
            <p className="text-2xl font-semibold text-white">{proPriceLabel}</p>
            <p className="text-xs text-muted">{storeLine}</p>
          </CardHeader>
          <CardContent>
            <ul className="space-y-2.5">
              {VALUE_MOMENT_PRICING_COPY.proFeatures.map((item) => (
                <PlanFeature key={item}>{item}</PlanFeature>
              ))}
            </ul>
            {plan === "pro" ? (
              <p className="mt-4 text-xs text-emerald-200">
                Pro preview active (local)
              </p>
            ) : (
              <Button
                type="button"
                className="mobile-touch-target mt-4 w-full min-h-11"
                onClick={handleUpgrade}
              >
                Get Pro in the mobile app
              </Button>
            )}
          </CardContent>
        </Card>
      </div>

      <PrivacyNotice className="mt-4" />

      {showCheckoutNotice ? (
        <Card className="mt-4 border-amber-500/20 bg-amber-500/5">
          <CardContent className="p-4 text-sm text-amber-50">
            Thanks — your interest was saved on this device ({clickCount}{" "}
            upgrade signal
            {clickCount === 1 ? "" : "s"} total). Purchases are available only
            in the ArchiveMe mobile app through the App Store or Google Play.
          </CardContent>
        </Card>
      ) : null}

      <section className="mt-10">
        <h2 className="text-sm font-semibold uppercase tracking-wider text-muted">
          {PRO_HEADLINE}
        </h2>
        <ul className="mt-4 space-y-3">
          {PRO_MEMORY_FEATURES.map((feature) => (
            <li
              key={feature.id}
              className="rounded-2xl border border-white/10 bg-white/[0.02] p-4"
            >
              <div className="flex items-start justify-between gap-2">
                <p className="font-medium text-white">{feature.title}</p>
                {feature.comingSoon ? (
                  <span className="shrink-0 rounded-full bg-white/5 px-2 py-0.5 text-[10px] uppercase tracking-wide text-muted">
                    Coming soon
                  </span>
                ) : null}
              </div>
              <p className="mt-1 line-clamp-3 text-sm text-zinc-300">
                {feature.description}
              </p>
            </li>
          ))}
        </ul>
      </section>

      {isProPreviewAllowed() ? (
        <Card className="mt-8 border-white/10">
          <CardContent className="flex flex-col gap-3 p-4 sm:flex-row sm:items-center sm:justify-between">
            <div className="flex items-start gap-2">
              <Lock className="mt-0.5 h-4 w-4 text-muted" />
              <p className="text-xs leading-relaxed text-muted">
                Local preview: toggle Pro on this device without payment. This
                preview never represents a real purchase.
              </p>
            </div>
            <Button
              type="button"
              variant="secondary"
              size="sm"
              className="mobile-touch-target shrink-0"
              onClick={togglePreviewPro}
            >
              {isProUser() ? "Turn off Pro preview" : "Preview Pro (local)"}
            </Button>
          </CardContent>
        </Card>
      ) : null}

      <p className="mt-8 text-center text-sm text-muted">
        <Link href="/" className="text-violet-200 hover:underline">
          Back to record
        </Link>
      </p>
    </>
  );
}
