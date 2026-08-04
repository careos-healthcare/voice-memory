"use client";

import { useEffect, useMemo, useRef } from "react";

import {
  WHY_MORE_EVIDENCE_BULLETS,
  WHY_MORE_EVIDENCE_CLOSER,
  WHY_MORE_EVIDENCE_HEADING,
  WHY_MORE_EVIDENCE_LEAD,
  WHY_MORE_EVIDENCE_SUBLEAD,
} from "@/lib/archive/evidence-education-copy";
import { buildEvidenceEducationVisibility } from "@/lib/archive/evidence-education";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { trackWhyEvidenceMattersSeen } from "@/lib/metrics/evidence-education-events";
import type { JournalEntry } from "@/types/journal";

interface WhyMoreEvidenceMattersProps {
  className?: string;
  entriesOverride?: JournalEntry[];
}

export function WhyMoreEvidenceMatters({
  className = "",
  entriesOverride,
}: WhyMoreEvidenceMattersProps) {
  const hydrated = useClientHydrated();
  const seenRef = useRef(false);

  const visibility = useMemo(
    () => (hydrated ? buildEvidenceEducationVisibility(entriesOverride) : null),
    [hydrated, entriesOverride],
  );

  useEffect(() => {
    if (!visibility?.show || !visibility.trigger || seenRef.current) return;
    seenRef.current = true;
    trackWhyEvidenceMattersSeen({
      reflectionCount: visibility.reflectionCount,
      trigger: visibility.trigger,
    });
  }, [visibility?.show, visibility?.trigger, visibility?.reflectionCount]);

  if (!visibility?.show) return null;

  return (
    <div
      className={`rounded-2xl border border-zinc-700/45 bg-zinc-900/35 px-4 py-4 text-left ${className}`}
      data-testid="why-more-evidence-matters"
      data-evidence-trigger={visibility.trigger}
      data-reflection-count={visibility.reflectionCount}
    >
      <p className="text-xs uppercase tracking-[0.16em] text-zinc-500">
        {WHY_MORE_EVIDENCE_HEADING}
      </p>
      <p className="mt-2 text-sm leading-relaxed text-zinc-200">{WHY_MORE_EVIDENCE_LEAD}</p>
      <p className="mt-2 text-sm leading-relaxed text-zinc-400">{WHY_MORE_EVIDENCE_SUBLEAD}</p>
      <p className="mt-3 text-sm text-zinc-500">Each new moment can:</p>
      <ul className="mt-2 list-inside list-disc space-y-1 text-sm text-zinc-400">
        {WHY_MORE_EVIDENCE_BULLETS.map((item) => (
          <li key={item}>{item}</li>
        ))}
      </ul>
      <p className="mt-3 text-sm leading-relaxed text-zinc-300">{WHY_MORE_EVIDENCE_CLOSER}</p>
    </div>
  );
}
