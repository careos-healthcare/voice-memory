"use client";

import Link from "next/link";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import { IDENTITY_FRAME_LABELS } from "@/types/calmness";
import type { CalmnessReport, IdentityFrame } from "@/types/calmness";

interface CalmUnderstandingCardProps {
  report: CalmnessReport;
  title?: string;
  subtitle?: string;
  highlightEntryId?: string;
  hideWhenEmpty?: boolean;
  showLandmarks?: boolean;
  className?: string;
}

const FRAME_ORDER: IdentityFrame[] = [
  "what_calmer",
  "what_clearer",
  "what_changed",
  "what_faded",
  "what_repeated",
];

function SilenceView({
  report,
  highlightEntryId,
}: {
  report: CalmnessReport;
  highlightEntryId?: string;
}) {
  const s = report.silence;
  if (!s) return null;

  if (s.mode === "quote") {
    return (
      <div className="space-y-4 py-2">
        <p className="text-lg leading-relaxed text-zinc-200">{s.primary}</p>
        {s.secondary ? (
          <p className="text-sm text-zinc-500">{s.secondary}</p>
        ) : null}
        {s.entryId ? (
          <Link
            href={`/entry/${s.entryId}`}
            className={`text-xs ${highlightEntryId === s.entryId ? "text-violet-300" : "text-zinc-600 hover:text-zinc-400"}`}
          >
            View entry
          </Link>
        ) : null}
      </div>
    );
  }

  if (s.mode === "contrast") {
    return (
      <div className="space-y-3 py-2">
        <p className="text-base leading-relaxed text-zinc-200">{s.primary}</p>
        {s.secondary ? (
          <p className="border-l border-white/10 pl-4 text-sm leading-relaxed text-zinc-500">
            {s.secondary}
          </p>
        ) : null}
      </div>
    );
  }

  return (
    <p className="py-2 text-lg leading-relaxed text-zinc-200">{s.primary}</p>
  );
}

export function CalmUnderstandingCard({
  report,
  title = "Over time",
  subtitle = "What your archive remembers — quietly",
  highlightEntryId,
  hideWhenEmpty = true,
  showLandmarks = false,
  className,
}: CalmUnderstandingCardProps) {
  if (!report.hasData) {
    if (hideWhenEmpty) return null;
    return (
      <Card className={`border-white/5 bg-white/[0.02] ${className ?? ""}`}>
        <CardContent className="py-12 text-center text-sm text-zinc-600">
          Not enough history yet for a clear read.
        </CardContent>
      </Card>
    );
  }

  const useSilence = report.silence && report.observations.length <= 2;

  return (
    <Card className={`border-white/5 bg-white/[0.02] ${className ?? ""}`}>
      <CardHeader className="pb-4">
        <CardTitle className="text-lg font-medium text-zinc-100">{title}</CardTitle>
        {subtitle ? (
          <p className="mt-1 text-sm leading-relaxed text-zinc-500">{subtitle}</p>
        ) : null}
      </CardHeader>
      <CardContent className="space-y-10">
        {useSilence ? (
          <SilenceView report={report} highlightEntryId={highlightEntryId} />
        ) : (
          <>
            {report.observations.length > 0 ? (
              <ul className="space-y-8">
                {report.observations.map((obs) => (
                  <li key={obs.id} className="space-y-2">
                    {obs.frame ? (
                      <p className="text-xs text-zinc-600">
                        {IDENTITY_FRAME_LABELS[obs.frame]}
                      </p>
                    ) : null}
                    <p className="text-base leading-relaxed text-zinc-200">{obs.text}</p>
                    {obs.detail && obs.confidence >= 62 ? (
                      <p className="text-sm leading-relaxed text-zinc-500">{obs.detail}</p>
                    ) : null}
                    {obs.quote && obs.confidence >= 65 ? (
                      <p className="text-sm italic text-zinc-600">
                        &ldquo;{obs.quote.slice(0, 100)}&rdquo;
                      </p>
                    ) : null}
                  </li>
                ))}
              </ul>
            ) : null}

            {FRAME_ORDER.some((f) => report.byFrame[f].length > 0) &&
            report.observations.length >= 2 ? (
              <div className="space-y-6 border-t border-white/5 pt-8">
                {FRAME_ORDER.map((frame) => {
                  const items = report.byFrame[frame];
                  if (items.length === 0) return null;
                  const extra = items.filter(
                    (i) => !report.observations.some((o) => o.id === i.id),
                  );
                  if (extra.length === 0) return null;
                  return (
                    <div key={frame}>
                      <p className="text-xs text-zinc-600">{IDENTITY_FRAME_LABELS[frame]}</p>
                      <ul className="mt-3 space-y-4">
                        {extra.slice(0, 1).map((obs) => (
                          <li key={obs.id} className="text-sm leading-relaxed text-zinc-400">
                            {obs.text}
                          </li>
                        ))}
                      </ul>
                    </div>
                  );
                })}
              </div>
            ) : null}
          </>
        )}

        {showLandmarks && report.landmarks.length > 0 ? (
          <div className="space-y-4 border-t border-white/5 pt-8">
            <p className="text-xs text-zinc-600">Memory landmarks</p>
            <ul className="space-y-4">
              {report.landmarks.slice(0, 3).map((lm) => (
                <li key={lm.id} className="text-sm leading-relaxed text-zinc-400">
                  {lm.text}
                </li>
              ))}
            </ul>
          </div>
        ) : null}
      </CardContent>
    </Card>
  );
}
