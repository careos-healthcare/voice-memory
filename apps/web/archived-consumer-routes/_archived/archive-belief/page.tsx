"use client";

import { useEffect, useState } from "react";

import { EvidenceArchiveHome } from "@/archived-components/_archived/archive/EvidenceArchiveHome";
import { PrimaryMain } from "@/components/layout/PrimaryMain";
import { SiteHeader } from "@/components/SiteHeader";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";

export default function ArchiveBeliefPage() {
  const [entries, setEntries] = useState<JournalEntry[]>([]);

  useEffect(() => {
    const id = requestAnimationFrame(() => {
      setEntries(getMemoryEligibleEntries());
    });
    return () => cancelAnimationFrame(id);
  }, []);

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />
        <PrimaryMain>
          <EvidenceArchiveHome entriesOverride={entries} />
        </PrimaryMain>
      </div>
    </div>
  );
}
