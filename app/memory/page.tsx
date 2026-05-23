"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { motion } from "framer-motion";
import { Brain, Shield, Sparkles } from "lucide-react";

import { FeedbackPrompt } from "@/components/FeedbackPrompt";
import { UpgradeCta } from "@/components/billing/UpgradeCta";
import { EmptyStateIntelligence } from "@/components/EmptyStateIntelligence";
import { EntityMemorySection } from "@/components/memory/EntityMemorySection";
import { ShareMemoryCardButton } from "@/components/memory/ShareMemoryCardButton";
import { PhraseMemoryCard } from "@/components/patterns/PhraseMemoryCard";
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
import { getAllEntries } from "@/lib/storage";

export default function MemoryPage() {
  const [snapshot, setSnapshot] = useState<EntityMemorySnapshot | null>(null);
  const [phrases, setPhrases] = useState<PhraseMemoryRecord[]>([]);

  useEffect(() => {
    trackLaunchEvent(LAUNCH_EVENTS.memoryPageOpened);
    const id = requestAnimationFrame(() => {
      const entries = getAllEntries();
      setSnapshot(buildEntityMemory());
      setPhrases(getTopPhrases(entries, 8));
    });
    return () => cancelAnimationFrame(id);
  }, []);

  const loading = snapshot === null;

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          className="mt-2"
        >
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">
            Entity memory
          </p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
            Memory
          </h1>
          <p className="mt-2 text-sm leading-relaxed text-zinc-400">
            Recurring people, topics, and phrases from your voice reflections —
            extracted locally on this device.
          </p>
        </motion.div>

        <div className="mt-4 flex items-start gap-3 rounded-2xl border border-white/10 bg-white/[0.03] px-4 py-3 text-xs text-zinc-500">
          <Shield className="mt-0.5 h-4 w-4 shrink-0 text-zinc-400" />
          Reflective mirror only — not therapy, not a diagnosis. Entity memory maps
          what you named, not what a clinician would label.
        </div>

        <div className="mt-6 space-y-5">
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
              <PhraseMemoryCard
                phrases={phrases}
                title="Words you keep returning to"
                subtitle="Repeated phrases, metaphors, and self-labels from your transcripts"
                maxItems={8}
              />
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
              {snapshot.mentionHighlights.length > 0 ? (
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

              <PhraseMemoryCard
                phrases={phrases}
                title="Words you keep returning to"
                subtitle="Repeated phrases, metaphors, and self-labels from your transcripts"
                maxItems={8}
              />

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
