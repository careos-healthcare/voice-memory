"use client";

import { cn } from "@/lib/utils";

const STEPS = ["Reflections", "Evidence", "Beliefs", "Belief Changes"] as const;

type ArchiveVisualModelProps = {
  className?: string;
  compact?: boolean;
};

export function ArchiveVisualModel({ className = "", compact = false }: ArchiveVisualModelProps) {
  return (
    <section
      className={cn(
        "rounded-2xl border border-white/10 bg-zinc-900/40 px-4 py-4",
        className,
      )}
      data-testid="archive-visual-model"
      aria-label="How the archive works"
    >
      <ol className="flex flex-col items-center gap-0">
        {STEPS.map((step, index) => (
          <li key={step} className="flex w-full max-w-xs flex-col items-center">
            <span
              className={cn(
                "w-full rounded-lg border border-violet-500/30 bg-violet-950/30 px-4 py-2 text-center font-medium text-violet-100",
                compact ? "text-xs" : "text-sm",
              )}
            >
              {step}
            </span>
            {index < STEPS.length - 1 ? (
              <span className="my-1 text-violet-400/70" aria-hidden>
                ↓
              </span>
            ) : null}
          </li>
        ))}
      </ol>
    </section>
  );
}
