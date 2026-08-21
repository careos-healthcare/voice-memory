"use client";

import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent } from "@/archived-components/_archived/ui/card";
import { BLIND_SPOT_PAGE } from "@/lib/blind-spots/blind-spot-copy";
import { FIRST_BLIND_SPOT_SIMULATOR } from "@/lib/product/first-blind-spot-simulator-copy";
import type { FirstBlindSpotExampleReview } from "@/lib/product/first-blind-spot-simulator";

interface FirstBlindSpotExampleReviewModalProps {
  example: FirstBlindSpotExampleReview;
  onClose: () => void;
}

export function FirstBlindSpotExampleReviewModal({
  example,
  onClose,
}: FirstBlindSpotExampleReviewModalProps) {
  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center bg-black/70 p-4 sm:items-center"
      role="dialog"
      aria-modal="true"
      aria-labelledby="first-blind-spot-example-title"
      data-testid="first-blind-spot-example-modal"
    >
      <button
        type="button"
        className="absolute inset-0 cursor-default"
        aria-label="Close example review"
        onClick={onClose}
      />
      <Card className="relative z-10 max-h-[min(90vh,720px)] w-full max-w-lg overflow-y-auto border-violet-500/20 bg-zinc-950">
        <CardContent className="space-y-5 p-5">
          <div>
            <p className="text-[11px] uppercase tracking-wide text-amber-200/80">
              {FIRST_BLIND_SPOT_SIMULATOR.exampleLabel}
            </p>
            <h2
              id="first-blind-spot-example-title"
              className="mt-2 text-base font-medium text-violet-100"
            >
              {FIRST_BLIND_SPOT_SIMULATOR.modalTitle}
            </h2>
            <p className="mt-2 text-xs leading-relaxed text-zinc-500">{example.disclaimer}</p>
          </div>

          <section className="space-y-2">
            <p className="text-xs uppercase tracking-wider text-zinc-500">Pattern</p>
            <p className="text-sm font-medium text-zinc-200">{example.patternHeadline}</p>
            <p className="text-sm leading-relaxed text-zinc-400">{example.observation}</p>
            <p className="text-sm leading-relaxed text-zinc-500">{example.possibleBelief}</p>
          </section>

          <section className="space-y-2 border-t border-white/5 pt-4">
            <p className="text-xs uppercase tracking-wider text-zinc-500">Evidence</p>
            <p className="text-xs text-zinc-500">{BLIND_SPOT_PAGE.evidenceLead}</p>
            <ul className="space-y-3">
              {example.evidenceQuotes.map((item) => (
                <li key={item.dateLabel} className="text-sm">
                  <span className="text-zinc-600">{item.dateLabel}</span>
                  <p className="mt-1 leading-relaxed text-zinc-400">&ldquo;{item.quote}&rdquo;</p>
                </li>
              ))}
            </ul>
          </section>

          <section className="space-y-2 border-t border-white/5 pt-4">
            <p className="text-xs uppercase tracking-wider text-zinc-500">
              {BLIND_SPOT_PAGE.likelyCostTitle}
            </p>
            <p className="text-sm leading-relaxed text-zinc-400">{example.possibleCost}</p>
          </section>

          <section className="space-y-3 border-t border-white/5 pt-4">
            <p className="text-xs uppercase tracking-wider text-zinc-500">
              {BLIND_SPOT_PAGE.experimentTitle}
            </p>
            <p className="text-xs text-zinc-500">{BLIND_SPOT_PAGE.experimentDisclaimer}</p>
            <div>
              <p className="text-[11px] uppercase tracking-wide text-zinc-600">
                {BLIND_SPOT_PAGE.experimentSmallThing}
              </p>
              <p className="mt-1 text-sm leading-relaxed text-zinc-300">
                {example.experimentSmallThing}
              </p>
            </div>
            <div>
              <p className="text-[11px] uppercase tracking-wide text-zinc-600">
                {BLIND_SPOT_PAGE.experimentTryNextTime}
              </p>
              <p className="mt-1 text-sm leading-relaxed text-zinc-400">
                {example.experimentTryNextTime}
              </p>
            </div>
          </section>

          <section className="space-y-2 border-t border-white/5 pt-4">
            <p className="text-xs uppercase tracking-wider text-zinc-500">
              {BLIND_SPOT_PAGE.sinceLastTimeTitle}
            </p>
            <p className="text-xs text-zinc-500">{BLIND_SPOT_PAGE.sinceLastTimeLead}</p>
            <ul className="space-y-2 text-sm leading-relaxed text-zinc-400">
              {example.whatChanged.map((line) => (
                <li key={line}>{line}</li>
              ))}
            </ul>
          </section>

          <Button type="button" variant="secondary" className="w-full" onClick={onClose}>
            Close
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}
