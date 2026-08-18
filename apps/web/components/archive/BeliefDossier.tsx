"use client";

import Link from "next/link";

import { ArchiveBeliefHeader } from "@/components/archive/ArchiveBeliefHeader";
import { ArchiveBeliefEvidenceSection } from "@/components/archive/ArchiveBeliefEvidenceSection";
import { ArchiveReputationCard } from "@/components/archive/ArchiveReputationCard";
import { WhyTheArchiveTrustsThis } from "@/components/archive/WhyTheArchiveTrustsThis";
import { ArchiveAccuracyTracker } from "@/components/archive/ArchiveAccuracyTracker";
import { ArchiveContradictionHistory } from "@/components/archive/ArchiveContradictionHistory";
import { ArchiveSilenceCard } from "@/components/archive/ArchiveSilenceCard";
import { BeliefSurvivalCard } from "@/components/archive/BeliefSurvivalCard";
import {
  BELIEF_DOSSIER_LEAD,
  BELIEF_DOSSIER_TITLE,
  BELIEF_DOSSIER_WHAT_WOULD_CHANGE_TITLE,
  buildBeliefDossier,
} from "@/lib/archive/belief-dossier";
import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import type { JournalEntry } from "@/types/journal";

interface BeliefDossierProps {
  className?: string;
  entriesOverride?: JournalEntry[];
  compact?: boolean;
  id?: string;
  /** When nested under archive home, the page-level belief header already rendered. */
  showBeliefHeader?: boolean;
}

export function BeliefDossier({
  className = "",
  entriesOverride,
  compact = false,
  id = "belief-dossier",
  showBeliefHeader = true,
}: BeliefDossierProps) {
  const hydrated = useClientHydrated();
  if (!hydrated) return null;

  const dossier = buildBeliefDossier(entriesOverride);
  if (!dossier) return null;

  return (
    <section
      id={id}
      className={`font-mono ${className}`}
      data-testid="belief-dossier"
      data-section="belief-dossier"
    >
      {showBeliefHeader ? (
        <ArchiveBeliefHeader entriesOverride={entriesOverride} className="mb-4" compact />
      ) : null}

      <div className="rounded-2xl border border-zinc-700/80 bg-zinc-950/80 px-4 py-5">
      <p className="text-[10px] uppercase tracking-[0.2em] text-zinc-500">{BELIEF_DOSSIER_TITLE}</p>
      <p className="mt-2 text-sm leading-relaxed text-zinc-400">{BELIEF_DOSSIER_LEAD}</p>

      <ArchiveReputationCard
        entriesOverride={entriesOverride}
        className="mt-4"
        compact
      />
      <WhyTheArchiveTrustsThis entriesOverride={entriesOverride} className="mt-3" />

      <BeliefSurvivalCard
        entriesOverride={entriesOverride}
        theoryId={dossier.theoryId}
        className="mt-4"
        variant="compact"
      />

      <ArchiveSilenceCard entriesOverride={entriesOverride} className="mt-4" />

      <ArchiveContradictionHistory
        entriesOverride={entriesOverride}
        theoryId={dossier.theoryId}
        className="mt-4"
      />

      <ArchiveAccuracyTracker entriesOverride={entriesOverride} className="mt-4" />

      <dl className="mt-4 grid gap-3 text-xs sm:grid-cols-2">
        <div>
          <dt className="text-zinc-600">Confidence</dt>
          <dd className="mt-0.5 text-zinc-200">{dossier.confidence}%</dd>
        </div>
        <div>
          <dt className="text-zinc-600">Status</dt>
          <dd className="mt-0.5 text-zinc-200">{dossier.statusLabel}</dd>
        </div>
        {dossier.firstAppearedLabel ? (
          <div className="sm:col-span-2">
            <dt className="text-zinc-600">First appeared</dt>
            <dd className="mt-0.5 text-zinc-400">{dossier.firstAppearedLabel}</dd>
          </div>
        ) : null}
        {dossier.lastChangedLabel ? (
          <div className="sm:col-span-2">
            <dt className="text-zinc-600">Last changed</dt>
            <dd className="mt-0.5 text-zinc-400">{dossier.lastChangedLabel}</dd>
          </div>
        ) : null}
      </dl>

      {!compact ? (
        <>
          <div className="mt-4">
            <p className="text-[10px] uppercase text-zinc-600">Supporting evidence</p>
            <div className="mt-2">
              <ArchiveBeliefEvidenceSection
                evidence={{
                  ...dossier.evidence,
                  contradictingQuotes: [],
                  costEvidenceLines: [],
                  predictionFailureLines: [],
                }}
              />
            </div>
          </div>

          {dossier.evidence.contradictingQuotes.length > 0 ? (
            <div className="mt-4">
              <p className="text-[10px] uppercase text-zinc-600">Contradicting evidence</p>
              <div className="mt-2">
                <ArchiveBeliefEvidenceSection
                  evidence={{
                    supportingQuotes: [],
                    contradictingQuotes: dossier.evidence.contradictingQuotes,
                    lifeAreas: [],
                    costEvidenceLines: [],
                    predictionFailureLines: [],
                  }}
                />
              </div>
            </div>
          ) : null}

          {dossier.lifeAreas.length > 0 ? (
            <p className="mt-3 text-xs text-zinc-500">
              Life areas: {dossier.lifeAreas.join(" · ")}
            </p>
          ) : null}

          {dossier.relatedBlindSpotHeadline ? (
            <p className="mt-3 text-xs text-zinc-500">
              Related blind spot:{" "}
              <Link href="/blind-spots" className="text-violet-300 hover:text-violet-200">
                {dossier.relatedBlindSpotHeadline}
              </Link>
            </p>
          ) : null}

          {dossier.relatedExperimentLine ? (
            <p className="mt-2 text-xs text-zinc-500">
              Related experiment: {dossier.relatedExperimentLine}
            </p>
          ) : null}
        </>
      ) : null}

      <div className="mt-5 border-t border-white/10 pt-4">
        <h3 className="text-[10px] uppercase tracking-widest text-zinc-500">
          {BELIEF_DOSSIER_WHAT_WOULD_CHANGE_TITLE}
        </h3>
        <ul className="mt-2 space-y-1.5 text-sm text-zinc-400">
          {dossier.whatWouldChangeLines.map((line) => (
            <li key={line} className="leading-relaxed">
              — {line}
            </li>
          ))}
        </ul>
      </div>
      </div>
    </section>
  );
}
