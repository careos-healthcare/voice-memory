"use client";

import type { ReactNode } from "react";

import {
  ARCHIVE_BELIEF_EVIDENCE_LABELS,
  ARCHIVE_BELIEF_EVIDENCE_TITLE,
} from "@/lib/archive/archive-belief-copy";
import type { ArchiveBeliefEvidence } from "@/types/archive-belief";

interface ArchiveBeliefEvidenceSectionProps {
  evidence: ArchiveBeliefEvidence;
}

export function ArchiveBeliefEvidenceSection({ evidence }: ArchiveBeliefEvidenceSectionProps) {
  const hasSupporting = evidence.supportingQuotes.length > 0;
  const hasContradictions = evidence.contradictingQuotes.length > 0;
  const hasLifeAreas = evidence.lifeAreas.length > 0;
  const hasCost = evidence.costEvidenceLines.length > 0;
  const hasPrediction = evidence.predictionFailureLines.length > 0;

  if (!hasSupporting && !hasContradictions && !hasLifeAreas && !hasCost && !hasPrediction) {
    return (
      <p className="text-sm text-zinc-500">
        More reflections may link dated quotes to this belief.
      </p>
    );
  }

  return (
    <div className="space-y-4">
      <h3 className="text-sm font-medium text-zinc-300">{ARCHIVE_BELIEF_EVIDENCE_TITLE}</h3>

      {hasSupporting ? (
        <EvidenceBlock title={ARCHIVE_BELIEF_EVIDENCE_LABELS.supporting}>
          {evidence.supportingQuotes.map((q) => (
            <Quote key={`s-${q.entryId}`} dateLabel={q.dateLabel} quote={q.quote} />
          ))}
        </EvidenceBlock>
      ) : null}

      {hasContradictions ? (
        <EvidenceBlock title={ARCHIVE_BELIEF_EVIDENCE_LABELS.contradictions}>
          {evidence.contradictingQuotes.map((q) => (
            <Quote key={`c-${q.entryId}`} dateLabel={q.dateLabel} quote={q.quote} />
          ))}
        </EvidenceBlock>
      ) : null}

      {hasLifeAreas ? (
        <EvidenceBlock title={ARCHIVE_BELIEF_EVIDENCE_LABELS.lifeAreas}>
          <p className="text-sm text-zinc-400">{evidence.lifeAreas.join(" · ")}</p>
        </EvidenceBlock>
      ) : null}

      {hasCost ? (
        <EvidenceBlock title={ARCHIVE_BELIEF_EVIDENCE_LABELS.costEvidence}>
          {evidence.costEvidenceLines.map((line) => (
            <p key={line} className="text-sm text-zinc-400">
              {line}
            </p>
          ))}
        </EvidenceBlock>
      ) : null}

      {hasPrediction ? (
        <EvidenceBlock title={ARCHIVE_BELIEF_EVIDENCE_LABELS.predictionFailures}>
          {evidence.predictionFailureLines.map((line) => (
            <p key={line} className="text-sm text-zinc-400">
              {line}
            </p>
          ))}
        </EvidenceBlock>
      ) : null}
    </div>
  );
}

function EvidenceBlock({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) {
  return (
    <div>
      <p className="text-[10px] uppercase tracking-wider text-zinc-600">{title}</p>
      <div className="mt-2 space-y-2">{children}</div>
    </div>
  );
}

function Quote({ dateLabel, quote }: { dateLabel: string; quote: string }) {
  return (
    <blockquote className="border-l-2 border-violet-400/30 pl-3 text-sm text-zinc-400">
      <span className="text-[10px] text-zinc-600">{dateLabel}</span>
      <p className="mt-0.5">&ldquo;{quote}&rdquo;</p>
    </blockquote>
  );
}
