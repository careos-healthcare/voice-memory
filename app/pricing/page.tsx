"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { motion } from "framer-motion";
import { Check, Crown, Lock } from "lucide-react";

import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  FREE_PLAN_FEATURES,
  FREE_ENTRY_LIMIT,
  getPlanId,
  getUpgradeClickEvents,
  isProUser,
  PRO_MEMORY_FEATURES,
  PRO_PLAN_FEATURES,
  PRO_PRICE_LABEL,
  setPlanId,
  trackUpgradeClick,
  type PlanId,
  type UpgradeClickSource,
} from "@/lib/subscription";
import { HONESTY_LINE, POSITIONING_TAGLINE } from "@/lib/product-copy";
import { getLockedEntryCount, getStoredEntryCount } from "@/lib/storage";

function PlanFeature({ children }: { children: React.ReactNode }) {
  return (
    <li className="flex items-start gap-2 text-sm text-zinc-300">
      <Check className="mt-0.5 h-4 w-4 shrink-0 text-emerald-400" />
      <span>{children}</span>
    </li>
  );
}

export default function PricingPage() {
  const searchParams = useSearchParams();
  const from = (searchParams.get("from") ?? "pricing") as UpgradeClickSource;

  const [plan, setPlan] = useState<PlanId>("free");
  const [clickCount, setClickCount] = useState(0);
  const [storedCount, setStoredCount] = useState(0);
  const [lockedCount, setLockedCount] = useState(0);
  const [showCheckoutNotice, setShowCheckoutNotice] = useState(false);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      setPlan(getPlanId());
      setClickCount(getUpgradeClickEvents().length);
      setStoredCount(getStoredEntryCount());
      setLockedCount(getLockedEntryCount());
    });
    return () => cancelAnimationFrame(id);
  }, []);

  const handleUpgrade = () => {
    trackUpgradeClick(from, "pricing_cta");
    setShowCheckoutNotice(true);
  };

  const togglePreviewPro = () => {
    const next: PlanId = isProUser() ? "free" : "pro";
    setPlanId(next);
    setPlan(next);
  };

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          className="mt-2 text-center sm:text-left"
        >
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">
            Private memory intelligence
          </p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
            Plans for your memory layer
          </h1>
          <p className="mt-2 text-sm leading-relaxed text-zinc-400">
            {POSITIONING_TAGLINE} Free stays local-first on your device. Pro
            unlocks the full intelligence layer across your reflection history.
          </p>
          <p className="mt-2 text-xs text-zinc-600">{HONESTY_LINE}</p>
          {storedCount > FREE_ENTRY_LIMIT && !isProUser() ? (
            <p className="mt-3 text-sm text-amber-200/90">
              You have {storedCount} reflections — {lockedCount} beyond the free
              limit are saved locally and unlock with Pro.
            </p>
          ) : null}
        </motion.div>

        <div className="mt-8 grid gap-4 sm:grid-cols-2">
          <Card className="border-white/10">
            <CardHeader>
              <CardTitle className="text-lg">Free</CardTitle>
              <p className="text-2xl font-semibold text-white">
                £0
                <span className="text-sm font-normal text-zinc-500"> / forever</span>
              </p>
            </CardHeader>
            <CardContent>
              <ul className="space-y-2.5">
                {FREE_PLAN_FEATURES.map((item) => (
                  <PlanFeature key={item}>{item}</PlanFeature>
                ))}
              </ul>
              {plan === "free" ? (
                <p className="mt-4 text-xs text-violet-300">Current plan</p>
              ) : (
                <Button
                  type="button"
                  variant="secondary"
                  size="sm"
                  className="mt-4"
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
                <Crown className="h-5 w-5 text-violet-300" />
                <CardTitle className="text-lg">Pro</CardTitle>
              </div>
              <p className="text-2xl font-semibold text-white">
                {PRO_PRICE_LABEL}
              </p>
              <p className="text-xs text-zinc-500">Placeholder pricing · no Stripe yet</p>
            </CardHeader>
            <CardContent>
              <ul className="space-y-2.5">
                {PRO_PLAN_FEATURES.map((item) => (
                  <PlanFeature key={item}>{item}</PlanFeature>
                ))}
              </ul>
              {plan === "pro" ? (
                <p className="mt-4 text-xs text-emerald-300">Pro preview active (local)</p>
              ) : (
                <Button type="button" className="mt-4 w-full" onClick={handleUpgrade}>
                  Upgrade to Pro
                </Button>
              )}
            </CardContent>
          </Card>
        </div>

        {showCheckoutNotice ? (
          <Card className="mt-4 border-amber-500/20 bg-amber-500/5">
            <CardContent className="p-4 text-sm text-amber-100/90">
              Thanks — your interest was saved on this device ({clickCount} upgrade
              signal{clickCount === 1 ? "" : "s"} total). Stripe checkout is not wired
              yet. Use &ldquo;Preview Pro&rdquo; below to test Pro features locally.
            </CardContent>
          </Card>
        ) : null}

        <section className="mt-10">
          <h2 className="text-sm font-semibold uppercase tracking-wider text-zinc-500">
            What Pro unlocks in your memory
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
                    <span className="shrink-0 rounded-full bg-white/5 px-2 py-0.5 text-[10px] uppercase tracking-wide text-zinc-500">
                      Coming soon
                    </span>
                  ) : null}
                </div>
                <p className="mt-1 text-sm text-zinc-400">{feature.description}</p>
              </li>
            ))}
          </ul>
        </section>

        <Card className="mt-8 border-white/10">
          <CardContent className="flex flex-col gap-3 p-4 sm:flex-row sm:items-center sm:justify-between">
            <div className="flex items-start gap-2">
              <Lock className="mt-0.5 h-4 w-4 text-zinc-500" />
              <p className="text-xs leading-relaxed text-zinc-500">
                Developer preview: toggle Pro locally without payment. Production
                billing will use Stripe when ready.
              </p>
            </div>
            <Button type="button" variant="secondary" size="sm" onClick={togglePreviewPro}>
              {isProUser() ? "Turn off Pro preview" : "Preview Pro (local)"}
            </Button>
          </CardContent>
        </Card>

        <p className="mt-8 text-center text-sm text-zinc-500">
          <Link href="/" className="text-violet-300 hover:underline">
            Back to reflect
          </Link>
        </p>
      </div>
    </div>
  );
}
