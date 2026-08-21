"use client";

import Link from "next/link";

import { Badge } from "@/archived-components/_archived/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type { ChangeDetectionReport, LongitudinalChange } from "@/types/changes";
import { helpsOrient } from "@/lib/patterns/usefulness-filter";

interface WhatChangedCardProps {
  report: ChangeDetectionReport;
  title?: string;
  subtitle?: string;
  hideWhenEmpty?: boolean;
  showEvidence?: boolean;
  quiet?: boolean;
  className?: string;
}

function ChangeItem({
  change,
  showEvidence,
}: {
  change: LongitudinalChange;
  showEvidence?: boolean;
}) {
  return (
    <li className="space-y-3">
      <p className="text-base leading-relaxed text-zinc-200">{change.summary}</p>
      {showEvidence ? (
        <div className="space-y-3 text-sm text-zinc-500">
          <p className="text-xs text-zinc-600">{change.dateRange.label}</p>
          {change.beforeEvidence.length > 0 ? (
            <div>
              <p className="text-xs uppercase tracking-wider text-zinc-600">Before</p>
              <ul className="mt-2 space-y-2">
                {change.beforeEvidence.map((ev) => (
                  <li key={ev.entryId} className="border-l border-white/10 pl-3">
                    <Link
                      href={`/entry/${ev.entryId}`}
                      className="text-xs text-zinc-600 hover:text-zinc-400"
                    >
                      {ev.dateLabel}
                      {ev.intensity !== undefined ? ` · ${ev.intensity}/10` : ""}
                    </Link>
                    <p className="mt-1 leading-relaxed text-zinc-500">{ev.snippet}</p>
                  </li>
                ))}
              </ul>
            </div>
          ) : null}
          {change.afterEvidence.length > 0 ? (
            <div>
              <p className="text-xs uppercase tracking-wider text-zinc-600">After</p>
              <ul className="mt-2 space-y-2">
                {change.afterEvidence.map((ev) => (
                  <li key={ev.entryId} className="border-l border-emerald-500/20 pl-3">
                    <Link
                      href={`/entry/${ev.entryId}`}
                      className="text-xs text-zinc-600 hover:text-zinc-400"
                    >
                      {ev.dateLabel}
                      {ev.intensity !== undefined ? ` · ${ev.intensity}/10` : ""}
                    </Link>
                    <p className="mt-1 leading-relaxed text-zinc-500">{ev.snippet}</p>
                  </li>
                ))}
              </ul>
            </div>
          ) : null}
          <Badge variant="secondary" className="text-[10px] capitalize">
            {change.confidenceLabel} · {change.confidence}
          </Badge>
        </div>
      ) : null}
    </li>
  );
}

export function WhatChangedCard({
  report,
  title = "What changed",
  subtitle,
  hideWhenEmpty = true,
  showEvidence = false,
  quiet = false,
  className,
}: WhatChangedCardProps) {
  const oriented = report.changes.filter((c) => helpsOrient(c.summary, c.confidence));
  const changes = quiet ? oriented.slice(0, 1) : oriented.slice(0, 3);

  if (changes.length === 0) {
    if (hideWhenEmpty) return null;
    return (
      <Card className={`border-white/5 bg-white/[0.02] ${className ?? ""}`}>
        <CardContent className="py-12 text-center text-sm text-zinc-600">
          Not enough history yet to name a clear change.
        </CardContent>
      </Card>
    );
  }

  const spacing = quiet ? "space-y-12" : "space-y-10";

  return (
    <Card className={`border-white/5 bg-white/[0.02] ${className ?? ""}`}>
      <CardHeader className={quiet ? "pb-6" : "pb-4"}>
        <CardTitle className="text-lg font-medium text-zinc-100">{title}</CardTitle>
        {subtitle ? (
          <p className="mt-1 text-sm leading-relaxed text-zinc-500">{subtitle}</p>
        ) : null}
      </CardHeader>
      <CardContent>
        <ul className={spacing}>
          {changes.map((change) => (
            <ChangeItem key={change.id} change={change} showEvidence={showEvidence} />
          ))}
        </ul>
      </CardContent>
    </Card>
  );
}
