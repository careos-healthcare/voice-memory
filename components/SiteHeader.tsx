import Link from "next/link";

import { APP_SUBTITLE } from "@/lib/product-copy";
import { cn } from "@/lib/utils";

interface SiteHeaderProps {
  className?: string;
  /** Entry / capture routes — logo only, no nav strip on small screens. */
  compact?: boolean;
}

const PRIMARY_NAV = [
  { href: "/journal", label: "Journal" },
  { href: "/memory", label: "Memory" },
  { href: "/search", label: "Search" },
  { href: "/pricing", label: "Pricing" },
  { href: "/account", label: "Account" },
] as const;

export function SiteHeader({ className, compact = false }: SiteHeaderProps) {
  return (
    <>
      <a
        href="#main-content"
        className="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-50 focus:rounded-full focus:bg-violet-600 focus:px-4 focus:py-2 focus:text-sm focus:font-medium focus:text-white"
      >
        Skip to main content
      </a>
    <header
      className={cn(
        "mx-auto flex w-full max-w-3xl items-center justify-between px-4 sm:px-6",
        compact ? "py-3" : "py-5",
        className,
      )}
    >
      <Link href="/" className="group flex items-center gap-2">
        <span className="flex h-8 w-8 items-center justify-center rounded-full bg-violet-500/15 text-sm font-semibold text-violet-300 ring-1 ring-violet-400/20">
          VM
        </span>
        <span className="flex flex-col">
          <span className="text-sm font-medium text-zinc-200 transition-colors group-hover:text-white">
            VoiceMemory
          </span>
          {!compact ? (
            <span className="hidden text-[10px] text-zinc-400 sm:block">
              {APP_SUBTITLE}
            </span>
          ) : null}
        </span>
      </Link>
      <nav
        aria-label="Primary"
        className={cn(
          "flex items-center gap-0.5 sm:gap-1",
          compact ? "hidden sm:flex" : "flex",
        )}
      >
        {PRIMARY_NAV.map(({ href, label }) => (
          <Link
            key={href}
            href={href}
            className="min-h-11 rounded-full px-2.5 py-2 text-xs text-zinc-300 transition-colors hover:bg-white/5 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-violet-400/50 sm:px-3 sm:text-sm"
          >
            {label}
          </Link>
        ))}
      </nav>
    </header>
    </>
  );
}
