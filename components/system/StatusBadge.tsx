import { cva, type VariantProps } from "class-variance-authority";

import { cn } from "@/lib/utils";

const badgeVariants = cva(
  "inline-flex items-center rounded-full px-2.5 py-0.5 text-[10px] font-medium uppercase tracking-wider",
  {
    variants: {
      tone: {
        neutral: "bg-white/5 text-zinc-400 ring-1 ring-white/10",
        success: "bg-emerald-500/10 text-emerald-300 ring-1 ring-emerald-500/20",
        warning: "bg-amber-500/10 text-amber-200 ring-1 ring-amber-500/20",
        error: "bg-rose-500/10 text-rose-200 ring-1 ring-rose-500/20",
        pro: "bg-violet-500/15 text-violet-200 ring-1 ring-violet-400/25",
      },
    },
    defaultVariants: { tone: "neutral" },
  },
);

export function StatusBadge({
  className,
  tone,
  children,
}: React.HTMLAttributes<HTMLSpanElement> & VariantProps<typeof badgeVariants>) {
  return <span className={cn(badgeVariants({ tone }), className)}>{children}</span>;
}
