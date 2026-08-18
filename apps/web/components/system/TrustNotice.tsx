import { Shield } from "lucide-react";

import { cn } from "@/lib/utils";

export function TrustNotice({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <aside
      className={cn(
        "flex gap-3 rounded-2xl border border-emerald-500/15 bg-emerald-500/5 px-4 py-3",
        className,
      )}
    >
      <Shield className="mt-0.5 h-4 w-4 shrink-0 text-emerald-400" aria-hidden />
      <p className="text-xs leading-relaxed text-emerald-50">{children}</p>
    </aside>
  );
}
