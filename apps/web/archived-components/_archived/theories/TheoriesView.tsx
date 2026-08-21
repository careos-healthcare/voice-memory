"use client";

import { useEffect, useMemo, useState } from "react";

import { EvolvingViewCard } from "@/archived-components/_archived/theories/EvolvingViewCard";
import { TheoryCard } from "@/archived-components/_archived/theories/TheoryCard";
import { Card, CardContent } from "@/archived-components/_archived/ui/card";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { THEORY_PAGE } from "@/lib/theories/theory-copy";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { TheoryTrackerReport } from "@/types/theory";

function TheorySection({
  title,
  theories,
}: {
  title: string;
  theories: import("@/types/theory").Theory[];
}) {
  if (theories.length === 0) return null;
  return (
    <section className="space-y-4">
      <h2 className="text-sm font-medium text-zinc-300">{title}</h2>
      <div className="space-y-4">
        {theories.map((theory) => (
          <TheoryCard key={theory.id} theory={theory} />
        ))}
      </div>
    </section>
  );
}

export function TheoriesView() {
  const entries = useMemo(() => getMemoryEligibleEntries(), []);
  const [report, setReport] = useState<TheoryTrackerReport | null>(null);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      setReport(buildTheoryTrackerReport(entries));
    });
    return () => cancelAnimationFrame(id);
  }, [entries]);

  if (report === null) {
    return (
      <Card>
        <CardContent className="py-16 text-center text-sm text-muted" role="status">
          Reading your thinking history…
        </CardContent>
      </Card>
    );
  }

  if (report.all.length === 0) {
    return (
      <Card className="border-dashed border-white/5">
        <CardContent className="py-14 text-center">
          <p className="text-sm font-medium text-zinc-400">{THEORY_PAGE.emptyTitle}</p>
          <p className="mt-2 text-sm leading-relaxed text-zinc-600">{THEORY_PAGE.emptyBody}</p>
        </CardContent>
      </Card>
    );
  }

  return (
    <div className="space-y-10">
      <EvolvingViewCard entriesOverride={entries} surface="theories" />
      <TheorySection title={THEORY_PAGE.strengtheningTitle} theories={report.strengthening} />
      <TheorySection title={THEORY_PAGE.weakeningTitle} theories={report.weakening} />
      <TheorySection title={THEORY_PAGE.activeTitle} theories={report.active} />
      <TheorySection title={THEORY_PAGE.resolvedTitle} theories={report.resolved} />
      <TheorySection title={THEORY_PAGE.retiredTitle} theories={report.retired} />
    </div>
  );
}
