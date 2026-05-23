"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { motion } from "framer-motion";
import { Brain, Sparkles } from "lucide-react";

import { FeedbackPrompt } from "@/components/FeedbackPrompt";
import { UpgradeCta } from "@/components/billing/UpgradeCta";
import { EmptyStateIntelligence } from "@/components/EmptyStateIntelligence";
import { EntityMemorySection } from "@/components/memory/EntityMemorySection";
import { ShareMemoryCardButton } from "@/components/memory/ShareMemoryCardButton";
import { PhraseMemoryCard } from "@/components/patterns/PhraseMemoryCard";
import { PatternInsightCard } from "@/components/patterns/PatternInsightCard";
import { ContradictionContinuityCard } from "@/components/patterns/ContradictionContinuityCard";
import { AvoidanceCard } from "@/components/patterns/AvoidanceCard";
import { EmotionalEvolutionCard } from "@/components/patterns/EmotionalEvolutionCard";
import { CalmUnderstandingCard } from "@/components/patterns/CalmUnderstandingCard";
import { SeeMorePanel } from "@/components/patterns/SeeMorePanel";
import { LongitudinalContinuityCard } from "@/components/patterns/LongitudinalContinuityCard";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  buildEntityMemory,
  formatEntityTypeLabel,
  type EntityMemorySnapshot,
} from "@/lib/entity-memory";
import { trackLaunchEvent, LAUNCH_EVENTS } from "@/lib/local-analytics";
import { getTopPhrases, type PhraseMemoryRecord } from "@/lib/patterns/phrase-memory";
import {
  buildPatternEngineReport,
  type PatternInsight,
} from "@/lib/patterns/pattern-engine";
import { detectAllContradictions, type Contradiction } from "@/lib/patterns/contradictions";
import { detectAllAvoidanceSignals, type AvoidanceSignal } from "@/lib/patterns/avoidance";
import { getEmotionalCycleInsights, type EvolutionInsight } from "@/lib/patterns/emotional-evolution";
import { buildContinuityReport } from "@/lib/patterns/continuity-engine";
import { buildCalmnessReport } from "@/lib/patterns/calmness";
import type { CalmnessReport } from "@/types/calmness";
import type { ContinuityReport } from "@/types/continuity";
import {
  hasStrongPatternEvidence,
  countsFromInsights,
} from "@/lib/patterns/evidence-priority";
import { getAllEntries } from "@/lib/storage";

export default function MemoryPage() {
  const [snapshot, setSnapshot] = useState<EntityMemorySnapshot | null>(null);
  const [phrases, setPhrases] = useState<PhraseMemoryRecord[]>([]);
  const [patternInsights, setPatternInsights] = useState<PatternInsight[]>([]);
  const [contradictions, setContradictions] = useState<Contradiction[]>([]);
  const [avoidanceSignals, setAvoidanceSignals] = useState<AvoidanceSignal[]>([]);
  const [cycleInsights, setCycleInsights] = useState<EvolutionInsight[]>([]);
  const [continuity, setContinuity] = useState<ContinuityReport | null>(null);
  const [calm, setCalm] = useState<CalmnessReport | null>(null);

  useEffect(() => {
    trackLaunchEvent(LAUNCH_EVENTS.memoryPageOpened);
    const id = requestAnimationFrame(() => {
      const entries = getAllEntries();
      setSnapshot(buildEntityMemory());
      setPhrases(getTopPhrases(entries, 8));
      setPatternInsights(buildPatternEngineReport(entries, { scope: "memory", limit: 8 }).insights);
      setContradictions(detectAllContradictions(entries));
      setAvoidanceSignals(detectAllAvoidanceSignals(entries));
      setCycleInsights(getEmotionalCycleInsights(entries));
      setContinuity(buildContinuityReport(entries, { scope: "archive", limit: 6 }));
      setCalm(buildCalmnessReport(entries, { scope: "archive", limit: 3 }));
    });
    return () => cancelAnimationFrame(id);
  }, []);

  const loading = snapshot === null;
  const strongPatterns = hasStrongPatternEvidence({
    ...countsFromInsights(patternInsights),
    contradictionCount: contradictions.length,
    phraseCount: phrases.length,
    avoidanceCount: avoidanceSignals.length,
    evolutionCount: cycleInsights.length,
  });

  const memoryPatternSections = (
    <>
      <PatternInsightCard
        insights={patternInsights}
        title="Further patterns"
        maxItems={6}
        primaryCount={2}
      />
      <ContradictionContinuityCard
        contradictions={contradictions}
        title="Tension across entries"
        subtitle=""
        maxItems={2}
      />
      {continuity?.hasData ? (
        <LongitudinalContinuityCard
          report={continuity}
          title="Continuity"
          subtitle=""
          maxItems={3}
          showSummaries={false}
          showArcs={false}
          showIdentity={false}
        />
      ) : null}
      <PhraseMemoryCard phrases={phrases} title="Repeated language" maxItems={4} />
      <AvoidanceCard signals={avoidanceSignals} title="What stayed vague" maxItems={3} />
      <EmotionalEvolutionCard insights={cycleInsights} title="Intensity over time" maxItems={3} />
    </>
  );

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          className="mt-2"
        >
          <p className="text-xs uppercase tracking-[0.2em] text-zinc-600">Memory</p>
          <h1 className="mt-3 text-3xl font-semibold tracking-tight text-white">Your archive</h1>
          <p className="mt-3 text-sm leading-relaxed text-zinc-500">
            People, themes, and phrases that recur — held locally, read quietly.
          </p>
        </motion.div>

        <div className="mt-12 space-y-12">
          <UpgradeCta
            source="memory"
            feature="entity_memory"
            headline="Entity memory across your full history"
            description="Free includes patterns from your last 7 reflections. Pro maps people, concerns, and themes across your complete private memory."
          />

          {loading ? (
            <Card>
              <CardContent className="py-12 text-center text-sm text-zinc-500">
                Reading your local memory…
              </CardContent>
            </Card>
          ) : !snapshot.hasData ? (
            <>
              <EmptyStateIntelligence className="mb-4" />
              <Card className="border-dashed">
              <CardContent className="px-6 py-12 text-center">
                <Brain className="mx-auto h-8 w-8 text-violet-300" />
                <p className="mt-4 text-lg font-medium text-white">No entity memory yet</p>
                <p className="mt-2 text-sm text-zinc-400">
                  Voice reflections build a map of people, concerns, and themes
                  that recur over time.
                </p>
                <Button asChild className="mt-6 w-full sm:w-auto">
                  <Link href="/">Start recording</Link>
                </Button>
              </CardContent>
            </Card>
            </>
          ) : snapshot.totalEntities === 0 ? (
            <>
              {calm?.hasData ? (
                <CalmUnderstandingCard report={calm} title="What stands out" />
              ) : null}
              <SeeMorePanel label="See more detail">{memoryPatternSections}</SeeMorePanel>
              <Card className="border-dashed">
                <CardContent className="px-6 py-12 text-center">
                  <Sparkles className="mx-auto h-8 w-8 text-violet-300" />
                  <p className="mt-4 text-lg font-medium text-white">
                    Still learning your world
                  </p>
                  <p className="mt-2 text-sm text-zinc-400">
                    Add a few more entries with clear names, themes, or concerns. We
                    only surface entities mentioned more than once (except close
                    relationships).
                  </p>
                  <Button asChild className="mt-6 w-full sm:w-auto" variant="secondary">
                    <Link href="/journal">View reflections</Link>
                  </Button>
                </CardContent>
              </Card>
            </>
          ) : (
            <>
              {calm?.hasData ? (
                <CalmUnderstandingCard
                  report={calm}
                  title="What stands out"
                  showLandmarks
                />
              ) : null}

              <SeeMorePanel label="See more detail">{memoryPatternSections}</SeeMorePanel>

              {!strongPatterns && snapshot.mentionHighlights.length > 0 ? (
                <Card className="border-violet-400/20 bg-gradient-to-br from-violet-500/10 via-transparent to-transparent">
                  <CardHeader className="pb-2">
                    <CardTitle className="text-base">Recurring mentions</CardTitle>
                    <p className="text-xs text-zinc-500">Evidence from past entries on this device</p>
                  </CardHeader>
                  <CardContent className="space-y-2">
                    {snapshot.mentionHighlights.map((item) => (
                      <p key={`${item.type}-${item.name}`} className="text-sm text-zinc-300">
                        You mentioned{" "}
                        <span className="font-medium capitalize text-white">
                          {item.name}
                        </span>{" "}
                        <span className="text-violet-300">
                          {item.mentionCount} times
                        </span>{" "}
                        <span className="text-zinc-600">
                          · {formatEntityTypeLabel(item.type)}
                        </span>
                      </p>
                    ))}
                    <ShareMemoryCardButton kind="memory_continuity" className="mt-4" />
                    <FeedbackPrompt
                      kind="memory_continuity"
                      targetKey="global"
                      label="Were these pattern observations useful?"
                      className="mt-4"
                    />
                  </CardContent>
                </Card>
              ) : null}

              <ShareMemoryCardButton kind="dominant_theme" />

              <EntityMemorySection
                title="Recurring people"
                subtitle="Names and relationships from your words"
                entities={snapshot.people}
                emptyLabel="No recurring people detected yet."
              />

              <EntityMemorySection
                title="Repeated threads"
                subtitle="Topics you circled without always naming directly"
                entities={snapshot.concerns}
                emptyLabel="No repeated threads detected yet."
              />

              <EntityMemorySection
                title="Stated intentions"
                subtitle="Goals and aims you expressed out loud"
                entities={snapshot.goals}
                emptyLabel="No stated intentions detected yet."
              />

              <EntityMemorySection
                title="Recurring topics"
                subtitle="Themes, places, and organizations"
                entities={snapshot.topics}
                emptyLabel="No recurring topics detected yet."
              />

              <p className="text-center text-xs leading-relaxed text-zinc-600">
                Extraction uses your transcript and reflection fields only. Nothing
                is sent to a server for entity memory.
              </p>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
