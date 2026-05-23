"use client";

import Link from "next/link";
import { AlertTriangle, Bug } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { PatternInsight } from "@/lib/patterns/pattern-engine";
import { typeLabel } from "@/lib/patterns/pattern-engine";
import {
  evidenceSourceLabel,
  specificityLabel,
} from "@/lib/patterns/specificity-score";

interface PatternSpecificityDebugPanelProps {
  insights: PatternInsight[];
  title?: string;
  compact?: boolean;
}

export function PatternSpecificityDebugPanel({
  insights,
  title = "Insight specificity debug",
  compact = false,
}: PatternSpecificityDebugPanelProps) {
  const weak = insights.filter((i) => i.specificity.isWeakOrGeneric);
  const sorted = [...insights].sort(
    (a, b) => b.specificity.specificityScore - a.specificity.specificityScore,
  );

  return (
    <Card className="border-amber-500/20">
      <CardHeader className="pb-2">
        <div className="flex items-center gap-2">
          <Bug className="h-4 w-4 text-amber-300" />
          <CardTitle className="text-base">{title}</CardTitle>
        </div>
        <p className="text-xs text-zinc-500">
          Top generated insights · specificity score · evidence sources · weak/generic warnings
        </p>
      </CardHeader>
      <CardContent className="space-y-4">
        {weak.length > 0 ? (
          <div className="rounded-xl border border-amber-500/30 bg-amber-500/5 px-3 py-2 text-xs text-amber-200/90">
            <div className="flex items-center gap-2 font-medium">
              <AlertTriangle className="h-3.5 w-3.5" />
              {weak.length} weak or generic insight{weak.length === 1 ? "" : "s"} detected
            </div>
          </div>
        ) : null}

        {sorted.length === 0 ? (
          <p className="text-sm text-zinc-500">No insights to score yet.</p>
        ) : (
          sorted.slice(0, compact ? 8 : 15).map((item, index) => (
            <div
              key={item.id}
              className={`rounded-xl border px-3 py-3 ${
                item.specificity.isWeakOrGeneric
                  ? "border-amber-500/20 bg-amber-950/10"
                  : "border-white/10 bg-black/20"
              }`}
            >
              <div className="flex flex-wrap items-start justify-between gap-2">
                <div className="flex items-start gap-2">
                  <span className="mt-0.5 text-[10px] font-medium text-zinc-500">
                    #{index + 1}
                  </span>
                  <div>
                    <p className="text-sm font-medium text-white">{item.title}</p>
                    <p className="mt-1 text-xs text-zinc-500">{item.detail}</p>
                  </div>
                </div>
                <div className="flex flex-wrap gap-1">
                  <Badge variant="secondary" className="text-[10px]">
                    {typeLabel(item.type)}
                  </Badge>
                  <Badge
                    variant="secondary"
                    className={`text-[10px] ${
                      item.specificity.isWeakOrGeneric ? "border-amber-500/30 text-amber-200" : ""
                    }`}
                  >
                    {item.specificity.specificityScore}/100 ·{" "}
                    {specificityLabel(item.specificity.specificityScore)}
                  </Badge>
                </div>
              </div>

              <p className="mt-2 text-xs text-zinc-400">
                Evidence count: {item.specificity.evidenceCount} · engine total{" "}
                {item.scores.total}/100
              </p>

              <div className="mt-2">
                <p className="text-[10px] uppercase tracking-wider text-zinc-600">
                  Why this felt specific
                </p>
                <ul className="mt-1 space-y-1">
                  {item.specificity.whyThisFeltSpecific.map((reason) => (
                    <li key={reason} className="text-xs text-zinc-400">
                      · {reason}
                    </li>
                  ))}
                </ul>
              </div>

              {item.specificity.evidenceSources.length > 0 ? (
                <div className="mt-2 flex flex-wrap gap-1">
                  {item.specificity.evidenceSources.map((source) => (
                    <Badge key={source} variant="outline" className="text-[10px]">
                      {evidenceSourceLabel(source)}
                    </Badge>
                  ))}
                </div>
              ) : null}

              {item.specificity.warnings.length > 0 ? (
                <ul className="mt-2 space-y-1">
                  {item.specificity.warnings.map((warning) => (
                    <li
                      key={warning}
                      className="flex items-start gap-1.5 text-xs text-amber-300/90"
                    >
                      <AlertTriangle className="mt-0.5 h-3 w-3 shrink-0" />
                      {warning}
                    </li>
                  ))}
                </ul>
              ) : null}

              {!compact && item.entryIds.length > 0 ? (
                <div className="mt-2 flex flex-wrap gap-2">
                  {item.entryIds.slice(0, 4).map((id) => (
                    <Link
                      key={id}
                      href={`/entry/${id}`}
                      className="text-[10px] text-violet-400 hover:text-violet-300"
                    >
                      Entry →
                    </Link>
                  ))}
                </div>
              ) : null}
            </div>
          ))
        )}
      </CardContent>
    </Card>
  );
}
