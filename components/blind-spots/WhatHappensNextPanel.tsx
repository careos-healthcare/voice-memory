"use client";

import Link from "next/link";

import { Button } from "@/components/ui/button";
import { WHAT_HAPPENS_NEXT } from "@/lib/product/evolving-understanding-copy";
import { trackWhatHappensNextClicked } from "@/lib/metrics/evolving-understanding-events";

interface WhatHappensNextPanelProps {
  className?: string;
}

export function WhatHappensNextPanel({ className = "" }: WhatHappensNextPanelProps) {
  return (
    <section
      className={`rounded-2xl border border-violet-500/15 bg-violet-950/10 px-4 py-4 ${className}`}
      data-testid="what-happens-next-panel"
    >
      <h3 className="text-sm font-medium text-violet-100/90">{WHAT_HAPPENS_NEXT.title}</h3>
      <ul className="mt-3 list-inside list-disc space-y-1.5 text-sm leading-relaxed text-zinc-400">
        {WHAT_HAPPENS_NEXT.bullets.map((line) => (
          <li key={line}>{line}</li>
        ))}
      </ul>
      <Button asChild type="button" size="sm" variant="secondary" className="mt-4">
        <Link
          href={WHAT_HAPPENS_NEXT.ctaHref}
          onClick={() => trackWhatHappensNextClicked()}
        >
          {WHAT_HAPPENS_NEXT.cta}
        </Link>
      </Button>
    </section>
  );
}
