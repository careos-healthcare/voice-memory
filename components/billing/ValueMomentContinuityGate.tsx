"use client";

import type { ReactNode } from "react";

import { ValueMomentPaywall } from "@/components/billing/ValueMomentPaywall";
import { readValueMomentState } from "@/lib/billing/value-moment-paywall";
import type { JournalEntry } from "@/types/journal";

interface ValueMomentContinuityGateProps {
  children: ReactNode;
  entriesOverride?: JournalEntry[];
  className?: string;
  /** Short line when continuity is gated but paywall already dismissed. */
  fallbackHint?: string;
}

/**
 * Shows deeper continuity content for Pro / free value window; otherwise paywall.
 */
export function ValueMomentContinuityGate({
  children,
  entriesOverride,
  className = "",
  fallbackHint = "Pro keeps tracking how theories change as your archive grows.",
}: ValueMomentContinuityGateProps) {
  const state = readValueMomentState(entriesOverride);

  if (!state.shouldGateArchiveContinuity) {
    return <>{children}</>;
  }

  return (
    <div className={className}>
      <ValueMomentPaywall surface="archive_continuity" entriesOverride={entriesOverride} />
      <p className="mt-3 text-center text-xs text-zinc-600">{fallbackHint}</p>
    </div>
  );
}
