"use client";

import Link from "next/link";
import type { ReactNode } from "react";
import { Mic } from "lucide-react";

import { Button } from "@/archived-components/_archived/ui/button";
import { Card, CardContent } from "@/archived-components/_archived/ui/card";
import {
  RECORD_CTA_LABEL,
  REFLECTION_MILESTONES,
  getAnticipatoryEmptyCopy,
} from "@/lib/product/anticipatory-memory-copy";
import { getStoredEntryCount } from "@/lib/storage";

export function AnticipatoryEmptyState({
  entryCount,
  icon,
  className,
  recordHref = "/record",
}: {
  entryCount?: number;
  icon?: ReactNode;
  className?: string;
  recordHref?: string;
}) {
  const count =
    entryCount ??
    (typeof window !== "undefined" ? getStoredEntryCount() : 0);
  const copy = getAnticipatoryEmptyCopy(count);

  return (
    <Card className={`border-dashed border-white/10 bg-white/[0.02] ${className ?? ""}`}>
      <CardContent className="flex flex-col items-center gap-4 px-6 py-14 text-center">
        {icon ? (
          <div className="flex h-14 w-14 items-center justify-center rounded-full bg-violet-500/10">
            {icon}
          </div>
        ) : null}
        <div className="max-w-md space-y-2">
          <p className="text-lg font-medium text-white">{copy.headline}</p>
          <p className="text-sm leading-relaxed text-zinc-400">{copy.body}</p>
        </div>
        {copy.showMilestones ? (
          <ul className="max-w-sm space-y-2 text-left text-xs leading-relaxed text-zinc-500">
            {REFLECTION_MILESTONES.map((m) => (
              <li key={m.after} className="flex gap-2">
                <span className="shrink-0 font-medium text-violet-300/90">
                  After {m.after}:
                </span>
                <span>{m.line}</span>
              </li>
            ))}
          </ul>
        ) : null}
        <Button asChild className="mobile-touch-target min-h-11" data-primary-cta="recorder">
          <Link href={recordHref}>
            <Mic className="h-4 w-4" />
            {RECORD_CTA_LABEL}
          </Link>
        </Button>
      </CardContent>
    </Card>
  );
}
