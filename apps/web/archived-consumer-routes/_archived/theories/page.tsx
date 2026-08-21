"use client";

import { useEvolvingUnderstandingReturnCheck } from "@/lib/metrics/evolving-understanding-return";
import { ContinuityStrip } from "@/archived-components/_archived/archive/ContinuityStrip";
import { WhyMoreEvidenceMatters } from "@/archived-components/_archived/archive/WhyMoreEvidenceMatters";
import { AnimatedReveal } from "@/archived-components/_archived/motion/AnimatedReveal";
import { InsightOutcomePromptStack } from "@/archived-components/_archived/insights/InsightOutcomePromptStack";
import { TheoriesView } from "@/archived-components/_archived/theories/TheoriesView";
import { PrimaryMain } from "@/components/layout/PrimaryMain";
import { SiteHeader } from "@/components/SiteHeader";
import { PrivacyNotice } from "@/archived-components/_archived/system";
import { BELIEF_DOMINANCE_ARCHIVE_TRUST } from "@/lib/product/belief-dominance-copy";
import { THEORY_PAGE } from "@/lib/theories/theory-copy";

export default function TheoriesPage() {
  useEvolvingUnderstandingReturnCheck("theories");

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <PrimaryMain className="mt-2">
          <AnimatedReveal className="mt-2">
            <p className="text-xs uppercase tracking-[0.2em] text-violet-200">
              {THEORY_PAGE.eyebrow}
            </p>
            <h1 className="mt-2 text-2xl font-semibold tracking-tight text-zinc-100">
              {THEORY_PAGE.title}
            </h1>
            <p className="sr-only">{BELIEF_DOMINANCE_ARCHIVE_TRUST}</p>
            <p className="mt-2 text-sm leading-relaxed text-muted">{THEORY_PAGE.lead}</p>
            <ContinuityStrip surface="theories" className="mt-3" />
          </AnimatedReveal>

          <PrivacyNotice className="mt-4" />
          <WhyMoreEvidenceMatters className="mt-4" />
          <p className="mt-2 text-xs leading-relaxed text-zinc-600">{THEORY_PAGE.disclaimer}</p>

          <InsightOutcomePromptStack className="mt-8" />

          <div className="mt-10">
            <TheoriesView />
          </div>
        </PrimaryMain>
      </div>
    </div>
  );
}
