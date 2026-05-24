"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { motion } from "framer-motion";

import { RevisitEntryLink } from "@/components/navigation/RevisitEntryLink";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import {
  buildIntentionsReport,
  formatIntentionSpan,
  setIntentionUserLabel,
} from "@/lib/intentions/long-term-intentions";
import type { IntentionsReport, LongTermIntention } from "@/types/long-term-intentions";

function IntentionRow({
  intention,
  onLabelSave,
}: {
  intention: LongTermIntention;
  onLabelSave: () => void;
}) {
  const [label, setLabel] = useState(intention.userLabel ?? "");

  useEffect(() => {
    setLabel(intention.userLabel ?? "");
  }, [intention.userLabel]);

  return (
    <li className="space-y-3">
      <p className="text-[15px] font-normal leading-[1.75] text-zinc-300/95">{intention.text}</p>
      <p className="text-xs text-zinc-600">{formatIntentionSpan(intention)}</p>
      <div className="flex flex-wrap gap-x-4 gap-y-2">
        {intention.sourceEntryIds.slice(-3).map((entryId, index) => (
          <RevisitEntryLink
            key={`${intention.id}-${entryId}`}
            entryId={entryId}
            source="memory_note"
            noteId={intention.id}
            noteText={intention.text}
            className="text-xs text-zinc-600/90 transition-colors hover:text-zinc-400"
          >
            {intention.sourceEntryIds.length === 1 ? "Source entry" : `Entry ${index + 1}`}
          </RevisitEntryLink>
        ))}
      </div>
      <label className="block text-xs text-zinc-600">
        <span className="sr-only">Optional label</span>
        <input
          value={label}
          onChange={(event) => setLabel(event.target.value)}
          onBlur={() => {
            setIntentionUserLabel(intention.id, label);
            onLabelSave();
          }}
          placeholder="Optional label"
          className="mt-1 w-full max-w-sm rounded-lg border border-white/[0.06] bg-transparent px-2 py-1.5 text-xs text-zinc-400 outline-none ring-violet-500/20 placeholder:text-zinc-700 focus:ring-2"
        />
      </label>
    </li>
  );
}

function IntentionSection({
  title,
  items,
  onLabelSave,
}: {
  title: string;
  items: LongTermIntention[];
  onLabelSave: () => void;
}) {
  if (items.length === 0) return null;

  return (
    <section className="space-y-8">
      <h2 className="text-xs uppercase tracking-[0.18em] text-zinc-600">{title}</h2>
      <ul className="space-y-12">
        {items.map((intention) => (
          <IntentionRow key={intention.id} intention={intention} onLabelSave={onLabelSave} />
        ))}
      </ul>
    </section>
  );
}

export default function IntentionsPage() {
  const [report, setReport] = useState<IntentionsReport | null>(null);

  const refresh = () => {
    setReport(buildIntentionsReport());
  };

  useEffect(() => {
    const id = requestAnimationFrame(refresh);
    return () => cancelAnimationFrame(id);
  }, []);

  const loading = report === null;

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />

        <motion.header initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-zinc-600">Intentions</p>
          <h1 className="mt-3 text-3xl font-semibold tracking-tight text-white">
            Things you keep coming back to
          </h1>
          <p className="mt-3 max-w-xl text-sm leading-relaxed text-zinc-500">
            Directions you named in your own voice — not a list to finish.
          </p>
        </motion.header>

        <div className="mt-16 space-y-20">
          {loading ? (
            <Card>
              <CardContent className="py-16 text-center text-sm text-zinc-600">
                Reading your archive…
              </CardContent>
            </Card>
          ) : !report.hasData ? (
            <div className="space-y-6">
              <p className="text-sm leading-relaxed text-zinc-500">
                When you say what you want or what you keep meaning to do, it will gather here quietly.
              </p>
              <Button asChild variant="secondary">
                <Link href="/">Record a reflection</Link>
              </Button>
            </div>
          ) : (
            <>
              <IntentionSection title="Still open" items={report.stillOpen} onLabelSave={refresh} />
              <IntentionSection
                title="Changed over time"
                items={report.changedOverTime}
                onLabelSave={refresh}
              />
              <IntentionSection title="Faded for now" items={report.fadedForNow} onLabelSave={refresh} />
            </>
          )}
        </div>

        <div className="mt-16 flex flex-wrap gap-4 text-sm">
          <Link href="/roundups" className="text-zinc-500 transition-colors hover:text-zinc-300">
            Roundups →
          </Link>
          <Link href="/memory" className="text-zinc-500 transition-colors hover:text-zinc-300">
            Memory →
          </Link>
        </div>
      </div>
    </div>
  );
}
