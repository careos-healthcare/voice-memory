"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

import { FOUNDER_INTERNAL_NAV } from "@/lib/internal/founder-focus-copy";
import { cn } from "@/lib/utils";

/** Founder navigation — command center and launch only (v3 consolidation). */
export function FounderInternalNav() {
  const pathname = usePathname();
  const items = [
    FOUNDER_INTERNAL_NAV.commandCenter,
    FOUNDER_INTERNAL_NAV.launch,
  ];

  return (
    <nav
      className="border-b border-white/10 bg-zinc-950/90"
      data-testid="founder-internal-nav"
      aria-label="Founder navigation"
    >
      <div className="mx-auto flex max-w-5xl gap-1 px-4 py-2 sm:px-6">
        {items.map((item) => {
          const active =
            pathname === item.href ||
            (item.href === "/internal" &&
              pathname?.startsWith("/internal") &&
              pathname !== "/internal/launch");
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "rounded-lg px-3 py-2 text-sm font-medium transition-colors",
                active
                  ? "bg-violet-500/20 text-violet-100"
                  : "text-zinc-500 hover:bg-white/5 hover:text-zinc-200",
              )}
            >
              {item.label}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
