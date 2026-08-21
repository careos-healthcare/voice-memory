"use client";

import Link from "next/link";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type { ThenVsNowComparison } from "@/types/continuity-moments";

interface ThenVsNowCardProps {
  comparison: ThenVsNowComparison;
  className?: string;
}

export function ThenVsNowCard({ comparison, className }: ThenVsNowCardProps) {
  if (comparison.confidence < 65) return null;

  return (
    <Card className={`border-white/5 bg-white/[0.02] ${className ?? ""}`}>
      <CardHeader className="pb-4">
        <CardTitle className="text-sm font-medium text-zinc-500">Then vs now</CardTitle>
        <p className="mt-1 text-sm text-zinc-400">{comparison.headline}</p>
      </CardHeader>
      <CardContent className="space-y-8">
        <div className="space-y-2">
          <p className="text-xs uppercase tracking-wider text-zinc-600">Then</p>
          <p className="text-sm leading-relaxed text-zinc-500">
            &ldquo;{comparison.then.snippet.slice(0, 180)}
            {comparison.then.snippet.length > 180 ? "…" : ""}&rdquo;
          </p>
          <Link
            href={`/entry/${comparison.then.entryId}`}
            className="text-xs text-zinc-600 hover:text-zinc-400"
          >
            {comparison.then.dateLabel}
          </Link>
        </div>
        <div className="space-y-2 border-t border-white/5 pt-8">
          <p className="text-xs uppercase tracking-wider text-zinc-600">Now</p>
          <p className="text-sm leading-relaxed text-zinc-300">
            &ldquo;{comparison.now.snippet.slice(0, 180)}
            {comparison.now.snippet.length > 180 ? "…" : ""}&rdquo;
          </p>
          <Link
            href={`/entry/${comparison.now.entryId}`}
            className="text-xs text-zinc-600 hover:text-zinc-400"
          >
            {comparison.now.dateLabel}
          </Link>
        </div>
      </CardContent>
    </Card>
  );
}
