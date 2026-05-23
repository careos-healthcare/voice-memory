import Link from "next/link";

import { cn } from "@/lib/utils";

interface SiteHeaderProps {
  className?: string;
}

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
        <span className="text-sm font-medium text-zinc-200 transition-colors group-hover:text-white">
          VoiceMemory
        </span>
      </Link>
      <nav className="flex items-center gap-1 sm:gap-2">
        <Link
          href="/memory"
          className="rounded-full px-3 py-2 text-sm text-zinc-400 transition-colors hover:bg-white/5 hover:text-white sm:px-4"
        >
          Memory
        </Link>
        <Link
          href="/weekly"
          className="hidden rounded-full px-3 py-2 text-sm text-zinc-400 transition-colors hover:bg-white/5 hover:text-white sm:inline-flex sm:px-4"
        >
          Weekly
        </Link>
        <Link
          href="/insights"
          className="hidden rounded-full px-3 py-2 text-sm text-zinc-400 transition-colors hover:bg-white/5 hover:text-white sm:inline-flex sm:px-4"
        >
          Insights
        </Link>
        <Link
          href="/export"
          className="rounded-full px-3 py-2 text-sm text-zinc-400 transition-colors hover:bg-white/5 hover:text-white sm:px-4"
        >
          Export
        </Link>
        <Link
          href="/search"
          className="hidden rounded-full px-3 py-2 text-sm text-zinc-400 transition-colors hover:bg-white/5 hover:text-white sm:inline-flex sm:px-4"
        >
          Search
        </Link>
        <Link
          href="/journal"
          className="rounded-full px-3 py-2 text-sm text-zinc-400 transition-colors hover:bg-white/5 hover:text-white sm:px-4"
        >
          Journal
        </Link>
      </nav>
    </header>
  );
}
