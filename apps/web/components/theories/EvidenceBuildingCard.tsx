"use client";

import { useMemo } from "react";

import { evidenceBuildingLabelForCount } from "@/lib/theories/personal-theory-status";
import { EVIDENCE_BUILDING_CARD_COPY } from "@/lib/theories/personal-theory-copy";
import { PERSONAL_THEORY_COPY } from "@/lib/theories/theory-confidence-movement";
import { buildArchiveValueSnapshot } from "@/lib/product/archive-value-progress";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { theoryToPersonalTheory } from "@/lib/theories/personal-theory-map";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { PersonalTheory } from "@/types/personal-theory";
import type { JournalEntry } from "@/types/journal";

interface EvidenceBuildingCardProps {
  className?: string;
  entriesOverride?: JournalEntry[];
  theory?: PersonalTheory;
  archiveRead?: string;
}

function statusLabelForTheory(theory: PersonalTheory): string {
  switch (theory.status) {
    case "strengthening":
      return "Strengthening";
    case "weakening":
      return "Weakening";
    case "resolved":
      return "Resolved";
    case "disproven":
      return "May no longer fit";
    default:
      return "Theory under review";
  }
}

export function EvidenceBuildingCard({
  className = "",
  entriesOverride,
  theory: theoryProp,
  archiveRead,
}: EvidenceBuildingCardProps) {
  const { reflectionCount, theory, statusLine } = useMemo(() => {
    const entries = entriesOverride ?? getMemoryEligibleEntries();
    const snapshot = buildArchiveValueSnapshot(entries);
    let topTheory = theoryProp;
    if (!topTheory && snapshot.reflectionCount >= 2) {
      const report = buildTheoryTrackerReport(entries, { persistSnapshots: false });
      const candidate = report.all
        .slice()
        .sort((a, b) => b.confidence - a.confidence)[0];
      if (candidate) topTheory = theoryToPersonalTheory(candidate);
    }
    return {
      reflectionCount: snapshot.reflectionCount,
      theory: topTheory,
      statusLine: evidenceBuildingLabelForCount(
        Math.max(1, Math.min(5, snapshot.reflectionCount)),
      ),
    };
  }, [entriesOverride, theoryProp]);

  if (reflectionCount < 1) return null;

  const evidenceLine = theory
    ? `${PERSONAL_THEORY_COPY.evidenceLabel}: ${theory.evidenceCount} reflection${theory.evidenceCount === 1 ? "" : "s"}`
    : `${PERSONAL_THEORY_COPY.evidenceLabel}: ${reflectionCount} reflection${reflectionCount === 1 ? "" : "s"}`;

  const confidenceLine = theory
    ? `${PERSONAL_THEORY_COPY.confidenceLabel}: ${theory.confidence}%`
    : null;

  const readLine =
    archiveRead ??
    theory?.whyConfidenceChanged ??
    EVIDENCE_BUILDING_CARD_COPY.archiveReadDefault;

  return (
    <div
      className={`rounded-2xl border border-violet-500/15 bg-violet-950/10 px-4 py-4 text-left ${className}`}
      data-testid="evidence-building-card"
    >
      <p className="text-xs uppercase tracking-wide text-violet-200/80">
        {EVIDENCE_BUILDING_CARD_COPY.buildingEvidence}
      </p>
      <p className="mt-1 text-[11px] text-zinc-600">
        {EVIDENCE_BUILDING_CARD_COPY.notLogging}
      </p>
      <dl className="mt-3 space-y-2 text-sm">
        <div>
          <dt className="text-[10px] uppercase tracking-wider text-zinc-600">
            {PERSONAL_THEORY_COPY.evidenceLabel}
          </dt>
          <dd className="mt-0.5 text-zinc-300">{evidenceLine.replace(/^Evidence: /, "")}</dd>
        </div>
        {confidenceLine ? (
          <div>
            <dt className="text-[10px] uppercase tracking-wider text-zinc-600">
              {PERSONAL_THEORY_COPY.confidenceLabel}
            </dt>
            <dd className="mt-0.5 text-zinc-300">{theory!.confidence}%</dd>
          </div>
        ) : null}
        <div>
          <dt className="text-[10px] uppercase tracking-wider text-zinc-600">
            {PERSONAL_THEORY_COPY.statusLabel}
          </dt>
          <dd className="mt-0.5 text-zinc-300">
            {theory ? statusLabelForTheory(theory) : statusLine}
          </dd>
        </div>
      </dl>
      <p className="mt-3 text-xs leading-relaxed text-zinc-500">
        <span className="text-zinc-600">Archive read: </span>
        {readLine}
      </p>
    </div>
  );
}
