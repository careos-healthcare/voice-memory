import Link from "next/link";

import { APP_SUBTITLE } from "@/lib/product-copy";
import { cn } from "@/lib/utils";

interface SiteHeaderProps {
  className?: string;
}

const PRIMARY_NAV = [
  { href: "/journal", label: "Memory" },
  { href: "/intentions", label: "Intentions" },
  { href: "/insights", label: "Timeline" },
  { href: "/search", label: "Search" },
  { href: "/pricing", label: "Pricing" },
] as const;

export function SiteHeader({ className }: SiteHeaderProps) {
  return (
    <header
      className={cn(
        "mx-auto flex w-full max-w-3xl items-center justify-between px-4 py-5 sm:px-6",
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
          <span className="hidden text-[10px] text-zinc-600 sm:block">
            {APP_SUBTITLE}
          </span>
        </span>
      </Link>
      <nav className="flex items-center gap-0.5 sm:gap-1">
        {PRIMARY_NAV.map(({ href, label }) => (
          <Link
            key={href}
            href={href}
            className="rounded-full px-2.5 py-2 text-xs text-zinc-400 transition-colors hover:bg-white/5 hover:text-white sm:px-3 sm:text-sm"
          >
            {label}
          </Link>
        ))}
      </nav>
    </header>
  );
}
