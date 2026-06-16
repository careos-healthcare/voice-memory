"use client";

import Link from "next/link";

import type { TheoryNotification } from "@/types/theory-notification";
import { cn } from "@/lib/utils";

interface TheoryNotificationCardProps {
  notification: TheoryNotification;
  onOpen: (id: string, route: string) => void;
}

export function TheoryNotificationCard({
  notification,
  onOpen,
}: TheoryNotificationCardProps) {
  const unread = !notification.readAt;

  return (
    <article
      className={cn(
        "rounded-xl border px-4 py-4 transition-colors",
        unread
          ? "border-violet-500/25 bg-violet-950/15"
          : "border-white/5 bg-black/20",
      )}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0 flex-1">
          <p className="text-sm font-medium text-zinc-200">{notification.title}</p>
          <p className="mt-2 text-sm leading-relaxed text-zinc-500">{notification.body}</p>
          {notification.evidenceSummary ? (
            <p className="mt-2 text-xs leading-relaxed text-zinc-600">
              {notification.evidenceSummary}
            </p>
          ) : null}
        </div>
        {unread ? (
          <span className="shrink-0 rounded-full bg-violet-500/20 px-2 py-0.5 text-[10px] uppercase tracking-wide text-violet-200">
            New
          </span>
        ) : null}
      </div>
      <div className="mt-4 flex flex-wrap items-center gap-3 text-xs text-zinc-600">
        <time dateTime={notification.createdAt}>
          {new Date(notification.createdAt).toLocaleString(undefined, {
            month: "short",
            day: "numeric",
            hour: "numeric",
            minute: "2-digit",
          })}
        </time>
        <Link
          href={notification.relatedRoute}
          className="text-violet-400 hover:text-violet-300"
          onClick={() => onOpen(notification.id, notification.relatedRoute)}
        >
          Open {notification.relatedRoute === "/discover" ? "Discover" : "Theories"}
        </Link>
      </div>
    </article>
  );
}
