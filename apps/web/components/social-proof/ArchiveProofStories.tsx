"use client";

import { getArchiveProofStories } from "@/lib/social-proof/archive-proof-stories";

interface ArchiveProofStoriesProps {
  className?: string;
}

export function ArchiveProofStories({ className = "" }: ArchiveProofStoriesProps) {
  const { label, stories } = getArchiveProofStories();

  return (
    <section
      className={`rounded-2xl border border-white/10 bg-zinc-900/30 px-4 py-4 ${className}`}
      data-testid="archive-proof-stories"
    >
      <p className="text-xs uppercase tracking-wide text-zinc-500">{label}</p>
      <ul className="mt-3 space-y-3">
        {stories.map((story) => (
          <li key={story.id} className="text-sm italic leading-relaxed text-zinc-400">
            “{story.quote}”
          </li>
        ))}
      </ul>
    </section>
  );
}
