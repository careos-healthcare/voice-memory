"use client";

import { useEffect, useRef } from "react";
import Link from "next/link";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import { BLIND_SPOT_EVENTS, trackBlindSpotEvent } from "@/lib/blind-spots/blind-spot-events";
import { observeFirstValueMoment } from "@/lib/retention/first-value-moments";
import { BLIND_SPOT_PAGE } from "@/lib/blind-spots/blind-spot-copy";
import type { PredictionReviewReport } from "@/types/blind-spot-acceleration";

interface PredictionReviewSectionProps {
  report: PredictionReviewReport;
  reflectionCount: number;
  archiveAgeDays: number;
}

function outcomeLabel(status: string): string {
  switch (status) {
    case "diverged":
      return "May have diverged";
    case "aligned":
      return "May have aligned";
    case "pending":
      return "Awaiting later reflection";
    default:
      return "Unclear";
  }
}

export function PredictionReviewSection({
  report,
  reflectionCount,
  archiveAgeDays,
}: PredictionReviewSectionProps) {
  const reviewTracked = useRef(false);
  const accuracyTracked = useRef(false);

  useEffect(() => {
    if (!report.hasData || reviewTracked.current) return;
    reviewTracked.current = true;
    trackBlindSpotEvent(BLIND_SPOT_EVENTS.predictionReviewOpened, {
      reflectionCount,
      archiveAgeDays,
    });
    observeFirstValueMoment("prediction_review_viewed");
  }, [report.hasData, reflectionCount, archiveAgeDays]);

  useEffect(() => {
    if (!report.hasData || report.accuracy.summaryLines.length === 0 || accuracyTracked.current) {
      return;
    }
    accuracyTracked.current = true;
    trackBlindSpotEvent(BLIND_SPOT_EVENTS.predictionAccuracyOpened, {
      reflectionCount,
      archiveAgeDays,
    });
  }, [report, reflectionCount, archiveAgeDays]);

  if (!report.hasData) return null;

  return (
    <section className="space-y-6 border-t border-white/5 pt-10">
      <div>
        <h2 className="text-lg font-semibold text-zinc-100">{BLIND_SPOT_PAGE.predictionTitle}</h2>
        <p className="mt-1 text-sm leading-relaxed text-zinc-500">{BLIND_SPOT_PAGE.predictionLead}</p>
      </div>

      {report.accuracy.summaryLines.length > 0 ? (
        <Card className="border-white/5 bg-black/20">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-zinc-300">
              Prediction accuracy summary
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-2">
            {report.accuracy.summaryLines.map((line) => (
              <p key={line} className="text-sm leading-relaxed text-zinc-400">
                {line}
              </p>
            ))}
          </CardContent>
        </Card>
      ) : null}

      <ul className="space-y-4">
        {report.items.map((item) => (
          <li key={item.candidate.id} className="rounded-xl border border-white/5 bg-black/15 p-4">
            <p className="text-[10px] uppercase tracking-wider text-zinc-500">
              {outcomeLabel(item.outcomeStatus)}
            </p>
            <div className="mt-3 space-y-3">
              <div>
                <p className="text-xs text-zinc-500">{BLIND_SPOT_PAGE.predictionQuoteLabel}</p>
                <p className="mt-1 text-xs text-zinc-600">{item.candidate.dateLabel}</p>
                <blockquote className="mt-1 border-l-2 border-amber-400/30 pl-3 text-sm text-zinc-200">
                  “{item.candidate.quote}”
                </blockquote>
                <Link
                  href={`/entry/${item.candidate.entryId}`}
                  className="mt-2 inline-block text-xs text-zinc-500 hover:text-violet-300"
                >
                  Open prediction reflection
                </Link>
              </div>
              {item.laterEvidence ? (
                <div>
                  <p className="text-xs text-zinc-500">{BLIND_SPOT_PAGE.predictionLaterLabel}</p>
                  <p className="mt-1 text-xs text-zinc-600">{item.laterEvidence.dateLabel}</p>
                  <blockquote className="mt-1 border-l-2 border-violet-400/30 pl-3 text-sm text-zinc-300">
                    “{item.laterEvidence.quote}”
                  </blockquote>
                  <Link
                    href={`/entry/${item.laterEvidence.entryId}`}
                    className="mt-2 inline-block text-xs text-zinc-500 hover:text-violet-300"
                  >
                    Open later reflection
                  </Link>
                </div>
              ) : null}
            </div>
            <p className="mt-3 text-xs leading-relaxed text-zinc-500">{item.outcomeSummary}</p>
          </li>
        ))}
      </ul>
    </section>
  );
}
