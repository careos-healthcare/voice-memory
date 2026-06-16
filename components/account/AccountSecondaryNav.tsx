"use client";

import Link from "next/link";

import { ARCHIVE_DETAIL_HUB_ROUTE } from "@/lib/product/archive-relevance";
import {
  ARCHIVE_DETAIL_NAV_LABEL,
} from "@/lib/product/simplicity-mode";
import {
  NAV_ARCHIVE_BELIEFS,
  NAV_ARCHIVE_INSIGHT,
  NAV_CHANGES,
  NAV_REFLECTION_LOG,
} from "@/lib/product/product-simplification-copy";

const SECONDARY_LINKS = [
  { href: ARCHIVE_DETAIL_HUB_ROUTE, label: "Archive detail hub" },
  { href: "/updates", label: NAV_CHANGES },
  { href: "/blind-spots", label: NAV_ARCHIVE_INSIGHT },
  { href: "/theories", label: NAV_ARCHIVE_BELIEFS },
  { href: "/memory", label: NAV_REFLECTION_LOG },
  { href: "/search", label: "Search" },
  { href: "/journal", label: "Journal" },
  { href: "/timeline", label: "Timeline" },
  { href: "/weekly", label: "Weekly" },
  { href: "/monthly", label: "Monthly" },
  { href: "/open-loops", label: "Open loops" },
  { href: "/insights", label: "Insights (legacy)" },
  { href: "/territories", label: "Territories" },
  { href: "/threads", label: "Threads" },
  { href: "/feelings-timeline", label: "Feelings timeline" },
  { href: "/roundups", label: "Roundups" },
  { href: "/bookmarks", label: "Bookmarks" },
  { href: "/reminders", label: "Reminders" },
  { href: "/archive", label: "Export archive" },
] as const;

export function AccountSecondaryNav({ className = "" }: { className?: string }) {
  return (
    <nav
      className={`rounded-2xl border border-white/10 bg-zinc-900/40 px-4 py-4 ${className}`}
      aria-label="Archive detail"
      data-testid="account-secondary-nav"
    >
      <p className="text-xs uppercase tracking-wide text-zinc-500">{ARCHIVE_DETAIL_NAV_LABEL}</p>
      <ul className="mt-3 space-y-2">
        {SECONDARY_LINKS.map((item) => (
          <li key={`${item.href}-${item.label}`}>
            <Link
              href={item.href}
              className="text-sm text-zinc-400 transition-colors hover:text-zinc-200"
            >
              {item.label}
            </Link>
          </li>
        ))}
      </ul>
    </nav>
  );
}
