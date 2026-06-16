"use client";

import Link from "next/link";

import { useClientHydrated } from "@/lib/hooks/use-client-hydrated";
import { APP_BRAND_NAME, APP_LOGO_INITIALS } from "@/lib/product/brand-copy";
import { APP_SUBTITLE } from "@/lib/product-copy";
import {
  ARCHIVE_NAV_ARCHIVE_MEANING,
  ARCHIVE_NAV_DISCOVER_MEANING,
} from "@/lib/product/archive-product-copy";
import { isReturningProductUser } from "@/lib/product/returning-home";
import { SIMPLICITY_PRIMARY_NAV } from "@/lib/product/simplicity-mode";
import { cn } from "@/lib/utils";

interface SiteHeaderProps {
  className?: string;
  /** Entry / capture routes — logo only, no nav strip on small screens. */
  compact?: boolean;
}

const PRIMARY_NAV = SIMPLICITY_PRIMARY_NAV.map((item) => ({
  ...item,
  returningOnly: item.label !== "Record" && item.label !== "Account",
}));

export function SiteHeader({ className, compact = false }: SiteHeaderProps) {
  const hydrated = useClientHydrated();
  const returning = hydrated && isReturningProductUser();
  const homeHref = returning ? "/archive-belief" : "/";

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
      data-testid="site-header"
    >
      <Link href={homeHref} className="group flex items-center gap-2" aria-label={APP_BRAND_NAME}>
        <span
          className="flex h-8 w-8 items-center justify-center rounded-full bg-violet-500/15 text-sm font-semibold text-violet-300 ring-1 ring-violet-400/20"
          aria-hidden
          data-testid="site-header-logo-initials"
        >
          {APP_LOGO_INITIALS}
        </span>
        <span className="flex flex-col">
          <span
            className="text-sm font-medium text-zinc-200 transition-colors group-hover:text-white"
            data-testid="site-header-brand-name"
          >
            {APP_BRAND_NAME}
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
        {PRIMARY_NAV.filter(
          (item) => !item.returningOnly || returning,
        ).map(({ href, label }) => {
          const title =
            label === "Archive"
              ? ARCHIVE_NAV_ARCHIVE_MEANING
              : label === "Archive Activity"
                ? ARCHIVE_NAV_DISCOVER_MEANING
                : undefined;
          return (
            <Link
              key={href}
              href={href}
              title={title}
              className="min-h-11 rounded-full px-2.5 py-2 text-xs text-zinc-300 transition-colors hover:bg-white/5 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-violet-400/50 sm:px-3 sm:text-sm"
            >
              {label}
            </Link>
          );
        })}
      </nav>
    </header>
    </>
  );
}
