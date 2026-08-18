"use client";

import { useMemo } from "react";

import { Card, CardContent } from "@/components/ui/card";
import {
  ARCHIVE_BELIEF_FEATURE_JUSTIFICATION,
  featuresMissingBeliefCentricSupport,
} from "@/lib/product/archive-belief-justification";

const PILLARS = ["Belief", "Evidence", "Change", "Trust"] as const;

export function ArchiveBeliefCenterPanel() {
  const rows = useMemo(() => Object.values(ARCHIVE_BELIEF_FEATURE_JUSTIFICATION), []);
  const hideCandidates = useMemo(() => featuresMissingBeliefCentricSupport(), []);

  const core = rows.filter((r) => r.centrality === "core");
  const supporting = rows.filter((r) => r.centrality === "supporting");

  return (
    <Card className="border-violet-500/25 bg-violet-950/10" data-testid="archive-belief-center-panel">
      <CardContent className="space-y-4 pt-6">
        <p className="text-sm font-medium text-violet-100">Archive belief centrality audit</p>
        <p className="text-sm text-zinc-400">
          Does this feature strengthen belief, evidence, change, or trust?
        </p>
        <p className="text-xs text-zinc-500">
          Core: {core.length} · Supporting: {supporting.length} · Candidate for hide:{" "}
          {hideCandidates.length}
        </p>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs text-zinc-400">
            <thead>
              <tr className="border-b border-white/10 text-zinc-500">
                <th className="py-2 pr-3">Feature</th>
                {PILLARS.map((p) => (
                  <th key={p} className="py-2 pr-2">
                    {p}
                  </th>
                ))}
                <th className="py-2">Tier</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row) => (
                <tr key={row.surface} className="border-b border-white/5">
                  <td className="py-2 pr-3 text-zinc-300">{row.surface}</td>
                  <td className="py-2 pr-2">{row.supportsBelief ? "✓" : "—"}</td>
                  <td className="py-2 pr-2">{row.supportsEvidence ? "✓" : "—"}</td>
                  <td className="py-2 pr-2">{row.supportsChange ? "✓" : "—"}</td>
                  <td className="py-2 pr-2">{row.supportsTrust ? "✓" : "—"}</td>
                  <td className="py-2 capitalize">{row.centrality.replace(/_/g, " ")}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {hideCandidates.length > 0 ? (
          <p className="text-xs text-amber-200/90">
            Candidate for hide: {hideCandidates.join(", ")}
          </p>
        ) : null}
      </CardContent>
    </Card>
  );
}
