"use client";

import Link from "next/link";
import { motion } from "framer-motion";
import { ArrowRight, GitBranch, Repeat } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { formatRelativeDate } from "@/lib/utils";
import type { MemoryContinuityReport, RelatedReflection } from "@/types/memory-continuity";

const REASON_LABELS: Record<RelatedReflection["matchReasons"][number], string> = {
  themes: "Themes",
  mood: "Mood",
  entities: "People & topics",
  keywords: "Wording",
  concern: "Concern",
  recommendation: "Next step you named",
};

function RelatedReflectionRow({
  item,
  index,
}: {
  item: RelatedReflection;
  index: number;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 6 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: index * 0.03 }}
    >
      <Link
        href={`/entry/${item.entry.id}`}
        className="group block rounded-xl border border-white/5 bg-black/10 p-4 transition-colors hover:border-violet-400/25 hover:bg-white/[0.03]"
      >
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-2">
              <Badge className="capitalize">{item.entry.reflection.mood}</Badge>
              <span className="text-xs text-zinc-500">
                {formatRelativeDate(item.entry.createdAt)}
              </span>
              {item.daysApart > 0 ? (
                <span className="text-xs text-zinc-600">
                  {item.daysApart} day{item.daysApart === 1 ? "" : "s"} earlier
                </span>
              ) : null}
            </div>
            <p className="mt-2 line-clamp-2 text-sm leading-relaxed text-zinc-400">
              {item.snippet}
            </p>
            {item.matchReasons.length > 0 ? (
              <div className="mt-2 flex flex-wrap gap-1.5">
                {item.matchReasons.map((reason) => (
                  <span
                    key={reason}
                    className="rounded-full bg-white/[0.04] px-2 py-0.5 text-[10px] text-zinc-500"
                  >
                    {REASON_LABELS[reason]}
                  </span>
                ))}
              </div>
            ) : null}
          </div>
          <ArrowRight className="mt-1 h-4 w-4 shrink-0 text-zinc-600 transition-transform group-hover:translate-x-0.5 group-hover:text-violet-300" />
        </div>
      </Link>
    </motion.div>
  );
}

interface MemoryContinuitySectionProps {
  report: MemoryContinuityReport;
}

export function MemoryContinuitySection({ report }: MemoryContinuitySectionProps) {
  if (!report.hasData) return null;

  return (
    <section className="space-y-4">
      <div className="flex items-center gap-2 px-1">
        <GitBranch className="h-4 w-4 text-violet-300/80" />
        <h2 className="text-sm font-medium uppercase tracking-wider text-zinc-500">
          Memory continuity
        </h2>
      </div>

      <Card className="border-white/10 bg-white/[0.02]">
        <CardHeader className="pb-3">
          <CardTitle className="text-base font-medium text-zinc-200">
            Related past reflections
          </CardTitle>
          <p className="text-xs leading-relaxed text-zinc-600">
            Local similarity across themes, mood, entities, and wording — reflective
            mirror only, not a diagnosis.
          </p>
        </CardHeader>
        <CardContent className="space-y-5">
          {report.mentionAgainLines.length > 0 ? (
            <div className="space-y-2 rounded-xl border border-violet-400/15 bg-violet-500/5 p-4">
              {report.mentionAgainLines.map((line) => (
                <p key={line} className="text-sm leading-relaxed text-violet-100/90">
                  {line}
                </p>
              ))}
            </div>
          ) : null}

          {report.patternCountLines.length > 0 ? (
            <div className="space-y-2">
              {report.patternCountLines.map((line) => (
                <p
                  key={line}
                  className="flex items-start gap-2 text-sm leading-relaxed text-zinc-400"
                >
                  <Repeat className="mt-0.5 h-3.5 w-3.5 shrink-0 text-zinc-600" />
                  {line}
                </p>
              ))}
            </div>
          ) : null}

          {report.repeatedConcerns.length > 0 ? (
            <div>
              <p className="text-[10px] font-medium uppercase tracking-wider text-zinc-600">
                Repeated concerns
              </p>
              <ul className="mt-2 space-y-1.5">
                {report.repeatedConcerns.map((concern) => (
                  <li key={concern.label} className="text-sm text-zinc-400">
                    <span className="capitalize text-zinc-300">{concern.label}</span>
                    <span className="text-zinc-600">
                      {" "}
                      · {concern.count} mention{concern.count === 1 ? "" : "s"}
                    </span>
                  </li>
                ))}
              </ul>
            </div>
          ) : null}

          {report.recurringEmotionalPatterns.length > 0 ? (
            <div>
              <p className="text-[10px] font-medium uppercase tracking-wider text-zinc-600">
                Recurring emotional patterns
              </p>
              <ul className="mt-2 space-y-1.5">
                {report.recurringEmotionalPatterns.map((pattern) => (
                  <li key={pattern.label} className="text-sm text-zinc-400">
                    <span className="capitalize text-zinc-300">{pattern.label}</span>
                    <span className="text-zinc-600">
                      {" "}
                      · {pattern.count}× · moods: {pattern.moods.join(", ")}
                    </span>
                  </li>
                ))}
              </ul>
            </div>
          ) : null}

          {report.lastMentioned.length > 0 ? (
            <div>
              <p className="text-[10px] font-medium uppercase tracking-wider text-zinc-600">
                Last mentioned
              </p>
              <ul className="mt-2 space-y-2">
                {report.lastMentioned.map((ref) => (
                  <li key={`${ref.kind}-${ref.label}`}>
                    <Link
                      href={`/entry/${ref.previousEntryId}`}
                      className="text-sm text-zinc-400 hover:text-violet-200"
                    >
                      <span className="capitalize text-zinc-300">{ref.label}</span>
                      <span className="text-zinc-600">
                        {" "}
                        · {ref.daysAgo} day{ref.daysAgo === 1 ? "" : "s"} ago
                      </span>
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ) : null}

          {report.similarFromPreviousWeeks.length > 0 ? (
            <div>
              <p className="text-[10px] font-medium uppercase tracking-wider text-zinc-600">
                Similar entries from previous weeks
              </p>
              <div className="mt-3 space-y-2">
                {report.similarFromPreviousWeeks.map((item, index) => (
                  <RelatedReflectionRow key={item.entry.id} item={item} index={index} />
                ))}
              </div>
            </div>
          ) : null}

          {report.relatedReflections.length > 0 ? (
            <div>
              <p className="text-[10px] font-medium uppercase tracking-wider text-zinc-600">
                Related reflections
              </p>
              <div className="mt-3 space-y-2">
                {report.relatedReflections.map((item, index) => (
                  <RelatedReflectionRow key={item.entry.id} item={item} index={index} />
                ))}
              </div>
            </div>
          ) : null}
        </CardContent>
      </Card>
    </section>
  );
}
