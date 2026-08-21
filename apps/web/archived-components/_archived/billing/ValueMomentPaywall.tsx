"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { Sparkles } from "lucide-react";

import { ArchiveHistorySummary } from "@/archived-components/_archived/archive/ArchiveHistorySummary";
import { ArchiveMilestones } from "@/archived-components/_archived/archive/ArchiveMilestones";
import { PaywallInterestPrompt } from "@/archived-components/_archived/billing/PaywallInterestPrompt";
import { PaywallRejectionPrompt } from "@/archived-components/_archived/billing/PaywallRejectionPrompt";
import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent } from "@/archived-components/_archived/ui/card";
import { startStripeCheckout } from "@/lib/billing/start-checkout";
import { useBillingPublicConfig } from "@/lib/billing/use-billing-public-config";
import { VALUE_MOMENT_PAYWALL_COPY } from "@/lib/billing/value-moment-paywall-copy";
import {
  markPostBlindSpotPaywallSeen,
  markPostDiscoverPaywallSeen,
  shouldShowValueMomentPaywall,
} from "@/lib/billing/value-moment-paywall";
import {
  trackValueMomentPaywallCtaClicked,
  trackValueMomentPaywallDismissed,
  trackValueMomentPaywallShown,
} from "@/lib/billing/value-moment-paywall-metrics";
import { useAuthPrompt } from "@/archived-components/_archived/auth/AuthPromptProvider";
import { trackUpgradeClick } from "@/lib/subscription";
import type { JournalEntry } from "@/types/journal";
import type { ValueMomentPaywallSurface } from "@/types/value-moment-paywall";

interface ValueMomentPaywallProps {
  surface: ValueMomentPaywallSurface;
  entriesOverride?: JournalEntry[];
  className?: string;
  onDismiss?: () => void;
}

type PaywallPhase = "paywall" | "rejection" | "interest";

function markSurfaceSeen(surface: ValueMomentPaywallSurface): void {
  if (surface === "blind_spot") markPostBlindSpotPaywallSeen();
  else if (surface === "discover") markPostDiscoverPaywallSeen();
  else {
    markPostBlindSpotPaywallSeen();
    markPostDiscoverPaywallSeen();
  }
}

export function ValueMomentPaywall({
  surface,
  entriesOverride,
  className = "",
  onDismiss,
}: ValueMomentPaywallProps) {
  const shownRef = useRef(false);
  const { requestAuth } = useAuthPrompt();
  const { billingLive, proPriceLabel } = useBillingPublicConfig();
  const show = shouldShowValueMomentPaywall(surface, entriesOverride);
  const [phase, setPhase] = useState<PaywallPhase>("paywall");

  useEffect(() => {
    if (show) setPhase("paywall");
  }, [show]);

  useEffect(() => {
    if (!show || shownRef.current) return;
    shownRef.current = true;
    trackValueMomentPaywallShown(surface);
  }, [show, surface]);

  const pricingFrom =
    surface === "blind_spot" ? "blind_spots" : surface === "discover" ? "discover" : "memory";

  const finishDismiss = () => {
    markSurfaceSeen(surface);
    onDismiss?.();
    setPhase("paywall");
  };

  const handleDismiss = () => {
    trackValueMomentPaywallDismissed(surface);
    setPhase("rejection");
  };

  const runCheckout = async () => {
    if (billingLive) {
      const result = await startStripeCheckout();
      if (result.ok) {
        window.location.href = result.url;
        return;
      }
    }
    window.location.href = `/pricing?from=${pricingFrom}&feature=value_moment_${surface}`;
  };

  const continueToCheckout = async () => {
    trackValueMomentPaywallCtaClicked(surface);
    trackUpgradeClick(pricingFrom, `value_moment_${surface}`);
    markSurfaceSeen(surface);

    if (!requestAuth("pro_paywall", () => void runCheckout())) {
      return;
    }
    await runCheckout();
  };

  const handleCta = () => {
    setPhase("interest");
  };

  if (!show && phase === "paywall") return null;

  if (phase === "rejection") {
    return (
      <PaywallRejectionPrompt
        className={className}
        surface={surface}
        source={pricingFrom}
        onDone={finishDismiss}
      />
    );
  }

  if (phase === "interest") {
    return (
      <PaywallInterestPrompt
        className={className}
        surface={surface}
        source={pricingFrom}
        onDone={() => void continueToCheckout()}
      />
    );
  }

  const copy = VALUE_MOMENT_PAYWALL_COPY;

  return (
    <Card
      className={`border-violet-400/25 bg-gradient-to-br from-violet-500/12 via-transparent to-emerald-500/5 ${className}`}
      data-testid={`value-moment-paywall-${surface}`}
    >
      <CardContent className="p-5 text-left">
        <p className="flex items-center gap-1.5 text-xs uppercase tracking-wider text-violet-200">
          <Sparkles className="h-3.5 w-3.5" />
          Continuity
        </p>
        <p className="mt-2 text-base font-medium text-white">{copy.headline}</p>
        <p className="mt-2 text-sm leading-relaxed text-zinc-300">{copy.body}</p>
        <div className="mt-4 space-y-3 rounded-lg border border-white/10 bg-black/20 p-3">
          <ArchiveMilestones entriesOverride={entriesOverride} />
          <ArchiveHistorySummary entriesOverride={entriesOverride} />
        </div>
        <p className="mt-2 text-xs leading-relaxed text-zinc-500">{copy.continuityLine}</p>
        <ul className="mt-4 space-y-1.5 text-sm text-zinc-400">
          {copy.proBullets.map((bullet) => (
            <li key={bullet} className="flex gap-2">
              <span className="text-violet-300/90">·</span>
              <span>{bullet}</span>
            </li>
          ))}
        </ul>
        <p className="mt-3 text-xs leading-relaxed text-zinc-600">{copy.trustLine}</p>
        <div className="mt-4 flex flex-col gap-2 sm:flex-row sm:items-center">
          <Button type="button" className="w-full sm:w-auto" onClick={handleCta}>
            {copy.cta}
          </Button>
          <Button type="button" variant="ghost" className="w-full sm:w-auto" onClick={handleDismiss}>
            {copy.secondary}
          </Button>
        </div>
        <p className="mt-2 text-xs text-zinc-600">
          {proPriceLabel}
          {billingLive ? (
            <>
              {" "}
              ·{" "}
              <Link href={`/pricing?from=${pricingFrom}`} className="text-violet-300 hover:underline">
                View plans
              </Link>
            </>
          ) : (
            <>
              {" "}
              ·{" "}
              <Link href={`/pricing?from=${pricingFrom}`} className="text-violet-300 hover:underline">
                See Pro details
              </Link>
            </>
          )}
        </p>
      </CardContent>
    </Card>
  );
}
