import Link from "next/link";

import { APP_BRAND_NAME, APP_LOGO_INITIALS } from "@/lib/product/brand-copy";
import { WEB_MARKETING_NAV } from "@/lib/site/web-marketing-nav";
import { cn } from "@/lib/utils";

interface SiteHeaderProps {
  className?: string;
  /** @deprecated Ignored — marketing header has a single layout. */
  compact?: boolean;
}

export function SiteHeader({ className }: SiteHeaderProps) {
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
          "mx-auto flex w-full max-w-3xl items-center justify-between px-4 py-5 sm:px-6",
          className,
        )}
        data-testid="site-header"
      >
        <Link href="/" className="group flex items-center gap-2" aria-label={APP_BRAND_NAME}>
          <span
            className="flex h-8 w-8 items-center justify-center rounded-full bg-violet-500/15 text-sm font-semibold text-violet-300 ring-1 ring-violet-400/20"
            aria-hidden
            data-testid="site-header-logo-initials"
          >
            {APP_LOGO_INITIALS}
          </span>
          <span
            className="text-sm font-medium text-zinc-200 transition-colors group-hover:text-white"
            data-testid="site-header-brand-name"
          >
            {APP_BRAND_NAME}
          </span>
        </Link>
        <nav aria-label="Primary" className="flex items-center gap-0.5 sm:gap-1">
          {WEB_MARKETING_NAV.map(({ href, label }) => (
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
