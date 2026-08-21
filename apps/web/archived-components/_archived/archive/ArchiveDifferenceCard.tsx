"use client";

import { useEffect, useState } from "react";

import {
  pickArchiveDifferenceExample,
  type ArchiveDifferenceExample,
} from "@/lib/archive/archive-difference-examples";
import { cn } from "@/lib/utils";

type ArchiveDifferenceCardProps = {
  className?: string;
};

export function ArchiveDifferenceCard({ className = "" }: ArchiveDifferenceCardProps) {
  const [example, setExample] = useState<ArchiveDifferenceExample>(() =>
    pickArchiveDifferenceExample(0),
  );

  useEffect(() => {
    const dayIndex = Math.floor(Date.now() / 86_400_000);
    setExample(pickArchiveDifferenceExample(dayIndex));
  }, []);

  return (
    <section
      className={cn(
        "rounded-2xl border border-violet-500/25 bg-violet-950/20 px-4 py-4",
        className,
      )}
      data-testid="archive-difference-card"
    >
      <div className="grid gap-3 sm:grid-cols-2">
        <div className="rounded-xl border border-white/10 bg-black/20 px-3 py-3">
          <p className="text-[10px] uppercase tracking-wider text-zinc-600">Without an archive</p>
          <p className="mt-2 text-sm italic text-zinc-400">&ldquo;{example.withoutArchive}&rdquo;</p>
        </div>
        <div className="rounded-xl border border-violet-500/30 bg-violet-950/30 px-3 py-3">
          <p className="text-[10px] uppercase tracking-wider text-violet-300/80">With an archive</p>
          <p className="mt-2 text-sm text-zinc-100">&ldquo;{example.withArchive}&rdquo;</p>
        </div>
      </div>
    </section>
  );
}
