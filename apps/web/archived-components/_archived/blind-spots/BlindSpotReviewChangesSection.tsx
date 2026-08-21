"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import { BLIND_SPOT_PAGE } from "@/lib/blind-spots/blind-spot-copy";
import type { BlindSpotReviewChanges } from "@/types/blind-spot-review-snapshot";

interface BlindSpotReviewChangesSectionProps {
  changes: BlindSpotReviewChanges;
}

export function BlindSpotReviewChangesSection({
  changes,
}: BlindSpotReviewChangesSectionProps) {
  if (!changes.hasPriorSnapshot) return null;

  return (
    <Card className="border-white/10 bg-zinc-900/40">
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-medium text-violet-100">
          {changes.sectionTitle}
        </CardTitle>
        <p className="text-xs leading-relaxed text-zinc-600">
          {BLIND_SPOT_PAGE.sinceLastTimeLead}
        </p>
      </CardHeader>
      <CardContent className="space-y-2 text-sm leading-relaxed text-zinc-400">
        {changes.hasMeaningfulChange ? (
          <ul className="space-y-2">
            {changes.lines.map((line) => (
              <li key={`${line.kind}-${line.text}`}>{line.text}</li>
            ))}
          </ul>
        ) : (
          <p className="text-zinc-500">{changes.noChangeMessage}</p>
        )}
      </CardContent>
    </Card>
  );
}
