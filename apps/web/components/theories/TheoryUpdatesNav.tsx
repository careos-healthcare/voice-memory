"use client";

import Link from "next/link";
import { Bell } from "lucide-react";
import { useEffect, useState } from "react";

import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { countUnreadTheoryNotifications } from "@/lib/theories/theory-notification-storage";
import { cn } from "@/lib/utils";

export function TheoryUpdatesNav({ className }: { className?: string }) {
  const hydrated = useClientHydrated();
  const [unread, setUnread] = useState(0);

  useEffect(() => {
    const refresh = () => setUnread(countUnreadTheoryNotifications());
    refresh();
    window.addEventListener("storage", refresh);
    window.addEventListener("voicememory-theory-notifications", refresh);
    return () => {
      window.removeEventListener("storage", refresh);
      window.removeEventListener("voicememory-theory-notifications", refresh);
    };
  }, [hydrated]);

  if (!hydrated || unread === 0) {
    return (
      <Link
        href="/updates"
        className={cn(
          "inline-flex min-h-11 items-center gap-1.5 rounded-full px-2.5 py-2 text-xs text-zinc-400 transition-colors hover:bg-white/5 hover:text-zinc-200 sm:px-3 sm:text-sm",
          className,
        )}
        aria-label="Changes"
      >
        <Bell className="h-4 w-4" />
        <span className="hidden sm:inline">Changes</span>
      </Link>
    );
  }

  return (
    <Link
      href="/updates"
      className={cn(
        "relative inline-flex min-h-11 items-center gap-1.5 rounded-full px-2.5 py-2 text-xs text-violet-200 transition-colors hover:bg-violet-500/10 sm:px-3 sm:text-sm",
        className,
      )}
      aria-label={`Updates, ${unread} unread`}
    >
      <Bell className="h-4 w-4" />
      <span className="hidden sm:inline">Updates</span>
      <span
        className="absolute -right-0.5 -top-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-violet-500 px-1 text-[10px] font-medium text-white"
        data-testid="theory-updates-unread-count"
      >
        {unread > 9 ? "9+" : unread}
      </span>
    </Link>
  );
}

export function notifyTheoryNotificationsChanged(): void {
  if (typeof window === "undefined") return;
  window.dispatchEvent(new Event("voicememory-theory-notifications"));
}
