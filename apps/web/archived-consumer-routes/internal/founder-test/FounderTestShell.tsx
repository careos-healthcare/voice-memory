"use client";

import Link from "next/link";

import { FounderTestPanel } from "@/archived-components/_archived/internal/FounderTestPanel";
import { SiteHeader } from "@/components/SiteHeader";
import type { DesignConsistencyFileReport } from "@/lib/internal/design-consistency-file-audit";

export function FounderTestShell({
  designReport,
}: {
  designReport: DesignConsistencyFileReport;
}) {
  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-5xl px-4 pb-20 sm:px-6">
        <SiteHeader />

        <header className="mt-2">
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">Founder only</p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
            Founder user-study checklist
          </h1>
          <p className="mt-2 max-w-2xl text-sm leading-relaxed text-zinc-400">
            Product development pauses here until Archive is the product in users’ minds. Run
            10–20 founder tests and record four gates: archive language, Archive before Discover
            after reflection 5, reflection 6 &gt; 5, and voluntary return to check what the archive
            believes. Do not build Archive History until these move.
          </p>
        </header>

        <div className="mt-8">
          <FounderTestPanel designReport={designReport} />
        </div>

        <div className="mt-10 flex flex-wrap gap-3 text-sm">
          <Link href="/internal" className="text-violet-300 hover:text-violet-200">
            Command center →
          </Link>
          <Link href="/internal/activation" className="text-violet-300 hover:text-violet-200">
            Activation →
          </Link>
        </div>
      </div>
    </div>
  );
}
