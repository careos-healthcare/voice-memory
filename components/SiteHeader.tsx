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
        <span className="flex flex-col">
          <span className="text-sm font-medium text-zinc-200 transition-colors group-hover:text-white">
            VoiceMemory
          </span>
          <span className="hidden text-[10px] text-zinc-600 sm:block">
            Private by default
          </span>
        </span>
      </Link>
      <nav className="flex items-center gap-1 sm:gap-2">
        <Link
          href="/memory"
          className="rounded-full px-3 py-2 text-sm text-zinc-400 transition-colors hover:bg-white/5 hover:text-white sm:px-4"
        >
          Past notes
        </Link>
        <Link
          href="/timeline"
          className="hidden rounded-full px-3 py-2 text-sm text-zinc-400 transition-colors hover:bg-white/5 hover:text-white sm:inline-flex sm:px-4"
        >
          Timeline
        </Link>
        <Link
          href="/weekly"
          className="hidden rounded-full px-3 py-2 text-sm text-zinc-400 transition-colors hover:bg-white/5 hover:text-white sm:inline-flex sm:px-4"
        >
          Weekly
        </Link>
        <Link
          href="/monthly"
          className="hidden rounded-full px-3 py-2 text-sm text-zinc-400 transition-colors hover:bg-white/5 hover:text-white sm:inline-flex sm:px-4"
        >
          Monthly
        </Link>
        <Link
          href="/seasons"
          className="hidden rounded-full px-3 py-2 text-sm text-zinc-400 transition-colors hover:bg-white/5 hover:text-white sm:inline-flex sm:px-4"
        >
          Seasons
        </Link>
        <Link
          href="/bookmarks"
          className="hidden rounded-full px-3 py-2 text-sm text-zinc-400 transition-colors hover:bg-white/5 hover:text-white sm:inline-flex sm:px-4"
        >
          Bookmarks
        </Link>
        <Link
          href="/threads"
          className="hidden rounded-full px-3 py-2 text-sm text-zinc-400 transition-colors hover:bg-white/5 hover:text-white sm:inline-flex sm:px-4"
        >
          Threads
        </Link>
        <Link
          href="/reminders"
          className="hidden rounded-full px-3 py-2 text-sm text-zinc-400 transition-colors hover:bg-white/5 hover:text-white sm:inline-flex sm:px-4"
        >
          Reminders
        </Link>
        <Link
          href="/pricing"
          className="rounded-full px-3 py-2 text-sm text-zinc-400 transition-colors hover:bg-white/5 hover:text-white sm:px-4"
        >
          Pricing
        </Link>
        <Link
          href="/demo"
          className="hidden rounded-full px-3 py-2 text-sm text-zinc-400 transition-colors hover:bg-white/5 hover:text-white sm:inline-flex sm:px-4"
        >
          Demo
        </Link>
        <Link
          href="/launch"
          className="hidden rounded-full px-3 py-2 text-sm text-zinc-400 transition-colors hover:bg-white/5 hover:text-white sm:inline-flex sm:px-4"
        >
          Launch
        </Link>
        <Link
          href="/archive"
          className="hidden rounded-full px-3 py-2 text-sm text-zinc-400 transition-colors hover:bg-white/5 hover:text-white sm:inline-flex sm:px-4"
        >
          Archive
        </Link>
        <Link
          href="/account"
          className="hidden rounded-full px-3 py-2 text-sm text-zinc-400 transition-colors hover:bg-white/5 hover:text-white sm:inline-flex sm:px-4"
        >
          Account
        </Link>
        <Link
          href="/settings"
          className="hidden rounded-full px-3 py-2 text-sm text-zinc-400 transition-colors hover:bg-white/5 hover:text-white sm:inline-flex sm:px-4"
        >
          Settings
        </Link>
        <Link
          href="/export"
          className="hidden rounded-full px-3 py-2 text-sm text-zinc-400 transition-colors hover:bg-white/5 hover:text-white sm:inline-flex sm:px-4"
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
          className="hidden rounded-full px-3 py-2 text-sm text-zinc-400 transition-colors hover:bg-white/5 hover:text-white sm:inline-flex sm:px-4"
        >
          Reflections
        </Link>
      </nav>
    </header>
  );
}
