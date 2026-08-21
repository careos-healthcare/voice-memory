"use client";

import { useMemo } from "react";
import { RefreshCw } from "lucide-react";

import { FounderModePreamble } from "@/archived-components/_archived/internal/FounderModePreamble";
import { NorthStarDashboard } from "@/archived-components/_archived/internal/NorthStarDashboard";
import { SiteHeader } from "@/components/SiteHeader";
import { Button } from "@/archived-components/_archived/ui/button";
import { NORTH_STAR_PAGE } from "@/lib/internal/founder-focus-copy";
import { buildNorthStarDashboard } from "@/lib/internal/north-star-report";

export default function NorthStarPage() {
  const view = useMemo(() => buildNorthStarDashboard(), []);

  return (
    <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
      <SiteHeader />

      <header className="mt-2 flex items-start justify-between gap-4">
        <div>
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">
            {NORTH_STAR_PAGE.eyebrow}
          </p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
            {NORTH_STAR_PAGE.title}
          </h1>
          <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
            {NORTH_STAR_PAGE.subheadline}
          </p>
        </div>
        <Button
          type="button"
          variant="ghost"
          size="sm"
          onClick={() => window.location.reload()}
        >
          <RefreshCw className="h-4 w-4" />
          Refresh
        </Button>
      </header>

      <div className="mt-6 space-y-6">
        <FounderModePreamble />
        <NorthStarDashboard initial={view} />
      </div>
    </div>
  );
}
