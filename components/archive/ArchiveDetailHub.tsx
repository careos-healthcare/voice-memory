"use client";

import Link from "next/link";

import {
  ARCHIVE_ADVANCED_DETAIL_DESCRIPTION,
  ARCHIVE_ADVANCED_DETAIL_EYEBROW,
  ARCHIVE_DETAIL_LABEL,
  DISCLOSURE_ADVANCED_CONTINUITY,
  DISCLOSURE_ADVANCED_CONTRADICTIONS,
  DISCLOSURE_ADVANCED_SIGNALS,
  DISCLOSURE_ADVANCED_TRUST,
  DISCLOSURE_ADVANCED_YOUR_ARCHIVE,
  DISCLOSURE_EVIDENCE_SECTION,
  DISCLOSURE_TIMELINE_SECTION,
} from "@/lib/archive/archive-disclosure-copy";
import { ARCHIVE_DETAIL_HUB_ROUTE } from "@/lib/product/archive-relevance";
import { ARCHIVE_DETAIL_NAV_LABEL } from "@/lib/product/simplicity-mode";
import { beliefJustificationFor } from "@/lib/product/archive-belief-justification";
import {
  BELIEF_DOMINANCE_ARCHIVE_CHANGE,
  BELIEF_DOMINANCE_EVIDENCE_FOR_BELIEF,
} from "@/lib/product/belief-dominance-copy";
import { cn } from "@/lib/utils";

const DETAIL_LINKS = [
  { href: "/archive-belief#evidence-locker", label: DISCLOSURE_EVIDENCE_SECTION },
  { href: "/archive-belief#belief-dossier", label: DISCLOSURE_ADVANCED_TRUST },
  { href: "/archive-belief#belief-dossier", label: DISCLOSURE_ADVANCED_SIGNALS },
  { href: "/archive-belief#belief-dossier", label: DISCLOSURE_ADVANCED_CONTINUITY },
  { href: "/archive-belief#belief-dossier", label: DISCLOSURE_ADVANCED_CONTRADICTIONS },
  { href: "/archive-belief#belief-dossier", label: DISCLOSURE_ADVANCED_YOUR_ARCHIVE },
  { href: "/blind-spots", label: BELIEF_DOMINANCE_EVIDENCE_FOR_BELIEF },
  { href: "/memory", label: "Saved words" },
  { href: "/search", label: "Search" },
  { href: "/discover", label: BELIEF_DOMINANCE_ARCHIVE_CHANGE },
  { href: "/timeline", label: DISCLOSURE_TIMELINE_SECTION },
] as const;

type ArchiveDetailHubProps = {
  className?: string;
  variant?: "inline" | "page";
};

export function ArchiveDetailHub({ className = "", variant = "inline" }: ArchiveDetailHubProps) {
  const hubReason = beliefJustificationFor("ArchiveDetailHub").archiveContributionReason;

  if (variant === "page") {
    return (
      <div className={cn("space-y-6", className)} data-testid="archive-detail-hub-page">
        <header>
          <p className="text-xs uppercase tracking-[0.2em] text-violet-300/80">
            {ARCHIVE_ADVANCED_DETAIL_EYEBROW}
          </p>
          <h1 className="mt-2 text-2xl font-medium text-zinc-50">{ARCHIVE_DETAIL_LABEL}</h1>
          <p className="mt-2 text-sm leading-relaxed text-zinc-500">
            {ARCHIVE_ADVANCED_DETAIL_DESCRIPTION}
          </p>
          <p className="mt-2 text-sm leading-relaxed text-zinc-600">{hubReason}</p>
        </header>
        <HubLinkList />
      </div>
    );
  }

  return (
    <nav
      className={cn(
        "rounded-2xl border border-white/10 bg-zinc-900/40 px-4 py-4",
        className,
      )}
      aria-label={ARCHIVE_DETAIL_NAV_LABEL}
      data-testid="archive-detail-hub"
    >
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <p className="text-xs uppercase tracking-wide text-zinc-500">{ARCHIVE_DETAIL_LABEL}</p>
        <Link
          href={ARCHIVE_DETAIL_HUB_ROUTE}
          className="text-xs text-violet-300 hover:text-violet-200"
        >
          View all →
        </Link>
      </div>
      <HubLinkList className="mt-3" compact />
    </nav>
  );
}

function HubLinkList({
  className = "",
  compact = false,
}: {
  className?: string;
  compact?: boolean;
}) {
  const links = compact ? DETAIL_LINKS.slice(0, 8) : DETAIL_LINKS;

  return (
    <ul className={cn("grid gap-2 sm:grid-cols-2", className)}>
      {links.map((item) => (
        <li key={`${item.href}-${item.label}`}>
          <Link
            href={item.href}
            className="block rounded-lg border border-white/5 bg-black/20 px-3 py-2.5 text-sm text-zinc-300 transition-colors hover:border-violet-500/30 hover:text-zinc-100"
          >
            {item.label}
          </Link>
        </li>
      ))}
    </ul>
  );
}
