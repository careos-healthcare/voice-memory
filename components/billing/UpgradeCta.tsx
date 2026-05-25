"use client";

import Link from "next/link";
import { Crown, Sparkles } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import {
  isProUser,
  PRO_PRICE_LABEL,
  trackUpgradeClick,
  type UpgradeClickSource,
} from "@/lib/subscription";

interface UpgradeCtaProps {
  source: UpgradeClickSource;
  feature: string;
  headline?: string;
  description?: string;
  compact?: boolean;
}

export function UpgradeCta({
  source,
  feature,
  headline = "Unlock full private memory intelligence",
  description = "Pro unlocks your full memory history, semantic search, weekly intelligence, entity memory, and export reports.",
  compact = false,
}: UpgradeCtaProps) {
  if (isProUser()) return null;

  const handleClick = () => {
    trackUpgradeClick(source, feature);
  };

  if (compact) {
    return (
      <div className="flex flex-col gap-3 rounded-2xl border border-violet-400/25 bg-violet-500/10 px-4 py-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="min-w-0">
          <p className="text-sm font-medium text-violet-100">{headline}</p>
          <p className="mt-0.5 text-xs text-zinc-400">{description}</p>
        </div>
        <Button asChild size="sm" className="shrink-0" onClick={handleClick}>
          <Link href={`/pricing?from=${source}`}>Upgrade · {PRO_PRICE_LABEL}</Link>
        </Button>
      </div>
    );
  }

  return (
    <Card className="border-violet-400/25 bg-gradient-to-br from-violet-500/15 via-transparent to-fuchsia-500/5">
      <CardContent className="p-5">
        <div className="flex items-start gap-3">
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-violet-500/20">
            <Crown className="h-5 w-5 text-violet-300" />
          </div>
          <div className="min-w-0 flex-1">
            <p className="flex items-center gap-1.5 text-xs uppercase tracking-wider text-violet-300/90">
              <Sparkles className="h-3.5 w-3.5" />
              VoiceMemory Pro
            </p>
            <p className="mt-1 text-base font-medium text-white">{headline}</p>
            <p className="mt-2 text-sm leading-relaxed text-zinc-400">
              {description}
            </p>
            <p className="mt-2 text-xs text-zinc-500">
              {PRO_PRICE_LABEL} · Billing not connected yet — tap to see plans
            </p>
            <Button asChild className="mt-4 w-full sm:w-auto" onClick={handleClick}>
              <Link href={`/pricing?from=${source}`}>View Pro plans</Link>
            </Button>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
