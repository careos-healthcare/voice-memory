"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

import {
  buildPatternActivationProgress,
  countPatternActivationReflections,
  shouldShowPatternActivationProgress,
} from "@/lib/product/pattern-activation";
import { PATTERN_ACTIVATION } from "@/lib/product/product-clarity-copy";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";

export function PatternActivationProgress({ className = "" }: { className?: string }) {
  const hydrated = useClientHydrated();
  const [count, setCount] = useState(0);

  useEffect(() => {
    setCount(countPatternActivationReflections());
  }, []);

  if (!hydrated || !shouldShowPatternActivationProgress(count)) return null;

  const progress = buildPatternActivationProgress(count);
  if (!progress) return null;

  return (
    <div
      className={`rounded-2xl border border-violet-500/20 bg-violet-950/15 px-4 py-3 text-left ${className}`}
      data-testid="pattern-activation-progress"
    >
      <p className="text-sm leading-relaxed text-violet-100/90">{progress.line}</p>
      {progress.readyForPatternReview ? (
        <div className="mt-3 flex flex-wrap gap-3 text-xs">
          <Link
            href={progress.blindSpotsHref}
            className="text-violet-300 underline-offset-2 hover:text-violet-200 hover:underline"
          >
            {PATTERN_ACTIVATION.blindSpotsCta}
          </Link>
          <Link
            href={progress.discoverHref}
            className="text-zinc-400 underline-offset-2 hover:text-zinc-300 hover:underline"
          >
            {PATTERN_ACTIVATION.discoverCta}
          </Link>
        </div>
      ) : null}
    </div>
  );
}
