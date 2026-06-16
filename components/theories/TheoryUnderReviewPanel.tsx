"use client";

import type { TheoryUncertaintyView } from "@/lib/theories/theory-uncertainty";
import { THEORY_UNCERTAINTY_COPY } from "@/lib/theories/theory-uncertainty";

interface TheoryUnderReviewPanelProps {
  view: TheoryUncertaintyView;
}

function statusTone(status: TheoryUncertaintyView["displayStatus"]): string {
  switch (status) {
    case "strengthening":
      return "text-violet-300/90";
    case "weakening":
      return "text-amber-300/80";
    case "unresolved":
      return "text-zinc-400";
    case "under_review":
      return "text-zinc-300";
    case "resolved":
      return "text-amber-200/80";
    case "retired":
      return "text-zinc-500";
    default:
      return "text-zinc-400";
  }
}

export function TheoryUnderReviewPanel({ view }: TheoryUnderReviewPanelProps) {
  return (
    <div
      className="mt-3 rounded-lg border border-dashed border-white/10 bg-white/[0.02] px-3 py-3"
      data-testid="theory-under-review-panel"
    >
      <p className="text-[10px] uppercase tracking-wider text-zinc-500">{view.panelTitle}</p>
      <p className="mt-1 text-xs leading-relaxed text-zinc-500">{view.panelLead}</p>
      <dl className="mt-3 grid gap-2 text-xs sm:grid-cols-2">
        <div>
          <dt className="text-zinc-600">{THEORY_UNCERTAINTY_COPY.supportingLabel}</dt>
          <dd className="mt-0.5 text-zinc-300" data-testid="theory-supporting-count">
            {view.supportingCount}
          </dd>
        </div>
        <div>
          <dt className="text-zinc-600">{THEORY_UNCERTAINTY_COPY.contradictingLabel}</dt>
          <dd className="mt-0.5 text-zinc-300" data-testid="theory-contradicting-count">
            {view.contradictingCount}
          </dd>
        </div>
        <div>
          <dt className="text-zinc-600">{THEORY_UNCERTAINTY_COPY.missingLabel}</dt>
          <dd className="mt-0.5 text-zinc-400" data-testid="theory-missing-count">
            {view.missingEvidenceCount}
          </dd>
          <dd className="mt-0.5 leading-relaxed text-zinc-600" data-testid="theory-missing-note">
            {view.missingEvidenceNote}
          </dd>
        </div>
        <div>
          <dt className="text-zinc-600">{THEORY_UNCERTAINTY_COPY.confidenceLabel}</dt>
          <dd className="mt-0.5 text-zinc-300" data-testid="theory-confidence-score">
            {view.confidence}
          </dd>
        </div>
        <div className="sm:col-span-2">
          <dt className="text-zinc-600">{THEORY_UNCERTAINTY_COPY.statusLabel}</dt>
          <dd className={`mt-0.5 font-medium ${statusTone(view.displayStatus)}`} data-testid="theory-display-status">
            {view.displayStatusLabel}
          </dd>
        </div>
      </dl>
    </div>
  );
}
