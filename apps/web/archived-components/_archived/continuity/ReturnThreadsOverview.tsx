"use client";

import { useEffect, useState } from "react";

import { ReturnThreadCard } from "@/archived-components/_archived/continuity/ReturnThreadCard";
import { buildReturnThreads } from "@/lib/continuity/return-threads";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { ReturnThreadGroups, ReturnThreadsReport } from "@/types/return-thread";

interface ThreadSectionProps {
  title: string;
  threads: ReturnThreadsReport["groups"][keyof ReturnThreadGroups];
}

function ThreadSection({ title, threads }: ThreadSectionProps) {
  if (threads.length === 0) return null;
  return (
    <section className="space-y-3">
      <h2 className="px-1 text-sm font-medium uppercase tracking-wider text-zinc-500">
        {title}
      </h2>
      <ul className="space-y-3">
        {threads.map((thread) => (
          <li key={thread.id}>
            <ReturnThreadCard thread={thread} />
          </li>
        ))}
      </ul>
    </section>
  );
}

interface ReturnThreadsOverviewProps {
  /** Pre-built report (SSR-safe tests); otherwise built client-side from storage. */
  report?: ReturnThreadsReport;
  compact?: boolean;
}

export function ReturnThreadsOverview({ report: reportProp, compact = false }: ReturnThreadsOverviewProps) {
  const [report, setReport] = useState<ReturnThreadsReport | null>(reportProp ?? null);

  useEffect(() => {
    if (reportProp) {
      setReport(reportProp);
      return;
    }
    const id = requestAnimationFrame(() => {
      setReport(buildReturnThreads(getMemoryEligibleEntries()));
    });
    return () => cancelAnimationFrame(id);
  }, [reportProp]);

  if (!report) {
    return (
      <p className="py-8 text-center text-sm text-zinc-600">Reading what came back…</p>
    );
  }

  if (!report.hasData) return null;

  const { groups } = report;
  const maxSections = compact ? 3 : 6;
  const sections: Array<{ title: string; threads: ThreadSectionProps["threads"] }> = [
    { title: "Words that returned", threads: groups.wordsReturned },
    { title: "Still unresolved", threads: groups.stillUnresolved },
    { title: "Earlier / now", threads: groups.earlierNow },
    { title: "You came back to this", threads: groups.cameBack },
    { title: "Repeated situations", threads: groups.repeatedSituations },
    { title: "People you mentioned again", threads: groups.peopleAgain },
  ].filter((s) => s.threads.length > 0);

  return (
    <div className="space-y-10">
      {sections.slice(0, maxSections).map((section) => (
        <ThreadSection key={section.title} title={section.title} threads={section.threads} />
      ))}
    </div>
  );
}
