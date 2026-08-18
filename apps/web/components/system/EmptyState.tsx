import type { ReactNode } from "react";

import { cn } from "@/lib/utils";

export function EmptyState({
  icon,
  title,
  description,
  action,
  className,
}: {
  icon?: ReactNode;
  title: string;
  description: string;
  action?: ReactNode;
  className?: string;
}) {
  return (
    <section
      className={cn(
        "rounded-2xl border border-white/10 bg-white/[0.02] px-6 py-12 text-center",
        className,
      )}
      aria-label={title}
    >
      {icon ? (
        <div className="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-violet-500/10 ring-1 ring-violet-400/20">
          {icon}
        </div>
      ) : null}
      <h2 className="text-lg font-medium text-zinc-100">{title}</h2>
      <p className="mx-auto mt-2 max-w-md text-sm leading-relaxed text-zinc-500">{description}</p>
      {action ? <div className="mt-6 flex justify-center">{action}</div> : null}
    </section>
  );
}
