"use client";

import Link from "next/link";

import { Badge } from "@/archived-components/_archived/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import { CHANGE_KIND_LABELS, type ChangeCandidate } from "@/types/changes";

interface ChangeDebugPanelProps {
  candidates: ChangeCandidate[];
}

function CandidateRow({ candidate }: { candidate: ChangeCandidate }) {
  return (
    <Card
      className={
        candidate.accepted
          ? "border-emerald-500/20 bg-emerald-500/[0.03]"
          : "border-white/5 bg-white/[0.02]"
      }
    >
      <CardHeader className="pb-2">
        <div className="flex flex-wrap items-center gap-2">
          <Badge variant={candidate.accepted ? "default" : "secondary"}>
            {candidate.accepted ? "Accepted" : "Rejected"}
          </Badge>
          <Badge variant="outline" className="text-[10px]">
            {CHANGE_KIND_LABELS[candidate.kind]}
          </Badge>
          <span className="text-xs tabular-nums text-zinc-500">
            confidence {candidate.confidence} ({candidate.confidenceLabel})
          </span>
        </div>
        <CardTitle className="mt-2 text-base font-medium text-zinc-200">
          {candidate.summary}
        </CardTitle>
        {!candidate.accepted && candidate.rejectionReason ? (
          <p className="text-xs text-amber-400/90">{candidate.rejectionReason}</p>
        ) : null}
      </CardHeader>
      <CardContent className="space-y-4 text-sm">
        <div>
          <p className="text-xs uppercase tracking-wider text-zinc-600">Score breakdown</p>
          <div className="mt-2 flex flex-wrap gap-2">
            {Object.entries(candidate.scoreBreakdown).map(([key, val]) => (
              <Badge key={key} variant="secondary" className="text-[10px]">
                {key}: {val}
              </Badge>
            ))}
          </div>
        </div>

        {candidate.warnings.length > 0 ? (
          <div>
            <p className="text-xs uppercase tracking-wider text-amber-500/80">Warnings</p>
            <ul className="mt-1 list-disc pl-4 text-xs text-amber-400/80">
              {candidate.warnings.map((w) => (
                <li key={w}>{w}</li>
              ))}
            </ul>
          </div>
        ) : null}

        <p className="text-xs text-zinc-600">Date range: {candidate.dateRange.label}</p>

        <div className="grid gap-4 sm:grid-cols-2">
          <div>
            <p className="text-xs uppercase tracking-wider text-zinc-600">Before evidence</p>
            <ul className="mt-2 space-y-2">
              {candidate.beforeEvidence.length === 0 ? (
                <li className="text-xs text-zinc-600">—</li>
              ) : (
                candidate.beforeEvidence.map((ev) => (
                  <li key={ev.entryId} className="rounded-lg border border-white/5 p-2">
                    <Link href={`/entry/${ev.entryId}`} className="text-xs text-violet-300">
                      {ev.dateLabel}
                    </Link>
                    <p className="mt-1 text-xs leading-relaxed text-zinc-400">{ev.snippet}</p>
                  </li>
                ))
              )}
            </ul>
          </div>
          <div>
            <p className="text-xs uppercase tracking-wider text-zinc-600">After evidence</p>
            <ul className="mt-2 space-y-2">
              {candidate.afterEvidence.length === 0 ? (
                <li className="text-xs text-zinc-600">—</li>
              ) : (
                candidate.afterEvidence.map((ev) => (
                  <li key={ev.entryId} className="rounded-lg border border-white/5 p-2">
                    <Link href={`/entry/${ev.entryId}`} className="text-xs text-violet-300">
                      {ev.dateLabel}
                    </Link>
                    <p className="mt-1 text-xs leading-relaxed text-zinc-400">{ev.snippet}</p>
                  </li>
                ))
              )}
            </ul>
          </div>
        </div>

        <p className="text-xs text-zinc-600">
          Related entries:{" "}
          {candidate.entryIds.map((id, i) => (
            <span key={id}>
              {i > 0 ? ", " : ""}
              <Link href={`/entry/${id}`} className="text-zinc-500 hover:text-zinc-300">
                {id.slice(0, 8)}…
              </Link>
            </span>
          ))}
        </p>
      </CardContent>
    </Card>
  );
}

export function ChangeDebugPanel({ candidates }: ChangeDebugPanelProps) {
  if (candidates.length === 0) {
    return (
      <Card>
        <CardContent className="py-12 text-center text-sm text-zinc-500">
          No change candidates detected.
        </CardContent>
      </Card>
    );
  }

  return (
    <div className="space-y-4">
      {candidates.map((c) => (
        <CandidateRow key={c.id} candidate={c} />
      ))}
    </div>
  );
}
