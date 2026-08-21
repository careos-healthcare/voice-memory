"use client";

import Link from "next/link";

import { Card, CardContent, CardHeader, CardTitle } from "@/archived-components/_archived/ui/card";
import type { ContinuityCallback, ContinuityMoment } from "@/types/continuity-moments";

interface ContinuityCallbacksProps {
  callbacks: ContinuityCallback[];
  title?: string;
  highlightEntryId?: string;
  hideWhenEmpty?: boolean;
  quiet?: boolean;
  className?: string;
}

export function ContinuityCallbacks({
  callbacks,
  title = "From your archive",
  highlightEntryId,
  hideWhenEmpty = true,
  quiet = false,
  className,
}: ContinuityCallbacksProps) {
  if (callbacks.length === 0) {
    if (hideWhenEmpty) return null;
    return null;
  }

  const spacing = quiet ? "space-y-6" : "space-y-5";
  const limit = quiet ? 1 : callbacks.length;

  return (
    <Card className={`border-white/5 bg-transparent ${className ?? ""}`}>
      <CardHeader className="pb-3">
        <CardTitle className="text-sm font-medium text-zinc-500">{title}</CardTitle>
      </CardHeader>
      <CardContent>
        <ul className={spacing}>
          {callbacks.slice(0, limit).map((cb) => (
            <li key={cb.id} className="text-base leading-relaxed text-zinc-300">
              {cb.text}
              {cb.anchorEntryId && cb.anchorEntryId !== highlightEntryId ? (
                <Link
                  href={`/entry/${cb.entryIds[cb.entryIds.length - 1]}`}
                  className="ml-2 text-xs text-zinc-600 hover:text-zinc-400"
                >
                  view
                </Link>
              ) : null}
            </li>
          ))}
        </ul>
      </CardContent>
    </Card>
  );
}

interface MemoryLandmarksStripProps {
  landmarks: ContinuityMoment[];
  hideWhenEmpty?: boolean;
  quiet?: boolean;
}

export function MemoryLandmarksStrip({
  landmarks,
  hideWhenEmpty = true,
  quiet = false,
}: MemoryLandmarksStripProps) {
  if (landmarks.length === 0) {
    if (hideWhenEmpty) return null;
    return null;
  }

  const limit = quiet ? 1 : 2;

  return (
    <div className={quiet ? "space-y-6 py-4" : "space-y-4 border-t border-white/5 py-8"}>
      <p className="text-xs text-zinc-600">Memory landmarks</p>
      <ul className={quiet ? "space-y-6" : "space-y-5"}>
        {landmarks.slice(0, limit).map((lm) => (
          <li key={lm.id} className="text-sm leading-relaxed text-zinc-400">
            {lm.text}
            {lm.dateLabel ? (
              <span className="mt-1 block text-xs text-zinc-600">{lm.dateLabel}</span>
            ) : null}
          </li>
        ))}
      </ul>
    </div>
  );
}
