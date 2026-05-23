"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { motion } from "framer-motion";
import { Brain, Sparkles } from "lucide-react";

import { EntityMemorySection } from "@/components/memory/EntityMemorySection";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  buildEntityMemory,
  formatEntityTypeLabel,
  type EntityMemorySnapshot,
} from "@/lib/entity-memory";

export default function MemoryPage() {
  const [snapshot, setSnapshot] = useState<EntityMemorySnapshot | null>(null);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      setSnapshot(buildEntityMemory());
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
            People, concerns, goals, and topics extracted conservatively from your
            journal — stored only on this device.
          </p>
        </motion.div>

        <div className="mt-6 space-y-5">
          {loading ? (
            <Card>
              <CardContent className="py-12 text-center text-sm text-zinc-500">
                Scanning your journal…
              </CardContent>
            </Card>
          ) : !snapshot.hasData ? (
            <Card className="border-dashed">
              <CardContent className="px-6 py-12 text-center">
                <Brain className="mx-auto h-8 w-8 text-violet-300" />
                <p className="mt-4 text-lg font-medium text-white">No memories yet</p>
                <p className="mt-2 text-sm text-zinc-400">
                  Record reflections to build your entity memory over time.
                </p>
                <Button asChild className="mt-6 w-full sm:w-auto">
                  <Link href="/">Start recording</Link>
                </Button>
              </CardContent>
            </Card>
          ) : snapshot.totalEntities === 0 ? (
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
                  <Link href="/journal">View journal</Link>
                </Button>
              </CardContent>
            </Card>
          ) : (
            <>
              {snapshot.mentionHighlights.length > 0 ? (
                <Card className="border-violet-400/20 bg-gradient-to-br from-violet-500/10 via-transparent to-transparent">
                  <CardHeader className="pb-2">
                    <CardTitle className="text-base">Often on your mind</CardTitle>
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
                  </CardContent>
                </Card>
              ) : null}

              <EntityMemorySection
                title="Recurring people"
                subtitle="Names and relationships from your words"
                entities={snapshot.people}
                emptyLabel="No recurring people detected yet."
              />

              <EntityMemorySection
                title="Recurring concerns"
                subtitle="Worries and fears you named"
                entities={snapshot.concerns}
                emptyLabel="No recurring concerns detected yet."
              />

              <EntityMemorySection
                title="Recurring goals"
                subtitle="Intentions and hopes you expressed"
                entities={snapshot.goals}
                emptyLabel="No recurring goals detected yet."
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
