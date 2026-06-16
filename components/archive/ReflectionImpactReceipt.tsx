"use client";

import { useMemo } from "react";

import { buildReflectionImpactReceipt } from "@/lib/archive/reflection-impact-receipt";
import type { JournalEntry } from "@/types/journal";

type ReflectionImpactReceiptProps = {
  entriesOverride?: JournalEntry[];
  newEntryId?: string;
  className?: string;
};

export function ReflectionImpactReceipt({
  entriesOverride,
  newEntryId,
  className = "",
}: ReflectionImpactReceiptProps) {
  const receipt = useMemo(
    () => buildReflectionImpactReceipt(entriesOverride, newEntryId),
    [entriesOverride, newEntryId],
  );

  return (
    <p
      className={`text-sm font-medium leading-relaxed text-emerald-200/95 ${className}`}
      data-testid="reflection-impact-receipt"
      data-impact-kind={receipt.kind}
      role="status"
    >
      {receipt.displayLabel}
    </p>
  );
}
