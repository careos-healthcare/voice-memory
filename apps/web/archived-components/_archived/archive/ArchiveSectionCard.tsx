import type { ReactNode } from "react";

import { cn } from "@/lib/utils";

/** Compact archive panel — matches thread card density. */
export function ArchiveSectionCard({
  title,
  icon,
  children,
  tone = "default",
  className,
}: {
  title: string;
  icon?: ReactNode;
  children: ReactNode;
  tone?: "default" | "danger";
  className?: string;
}) {
  return (
    <section
      className={cn(
        "rounded-2xl border bg-white/[0.02] p-4",
        tone === "danger" ? "border-red-500/20" : "border-white/10",
        className,
      )}
    >
      <h2
        className={cn(
          "flex items-center gap-2 text-base font-medium",
          tone === "danger" ? "text-red-200/90" : "text-zinc-200",
        )}
      >
        {icon}
        {title}
      </h2>
      <div className="mt-3 space-y-2 text-sm leading-relaxed text-zinc-500">{children}</div>
    </section>
  );
}
