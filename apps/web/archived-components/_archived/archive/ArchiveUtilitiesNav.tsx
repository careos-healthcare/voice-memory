"use client";

import Link from "next/link";

import {
  NAV_ARCHIVE_INSIGHT,
  NAV_REFLECTION_LOG,
} from "@/lib/product/product-simplification-copy";

const UTILITIES = [
  { href: "/discover", label: "Changes (Discover)" },
  { href: "/blind-spots", label: NAV_ARCHIVE_INSIGHT },
  { href: "/memory", label: NAV_REFLECTION_LOG },
] as const;

export function ArchiveUtilitiesNav({ className = "" }: { className?: string }) {
  return (
    <nav
      className={`rounded-2xl border border-white/10 bg-zinc-900/30 px-4 py-3 ${className}`}
      aria-label="Archive utilities"
      data-testid="archive-utilities-nav"
    >
      <p className="text-xs uppercase tracking-wide text-zinc-600">Archive utilities</p>
      <ul className="mt-2 flex flex-wrap gap-x-4 gap-y-1">
        {UTILITIES.map((item) => (
          <li key={item.href}>
            <Link
              href={item.href}
              className="text-xs text-zinc-500 hover:text-zinc-300"
            >
              {item.label}
            </Link>
          </li>
        ))}
      </ul>
    </nav>
  );
}
