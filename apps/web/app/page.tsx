import type { Metadata } from "next";
import Link from "next/link";

import { SiteFooter } from "@/components/SiteFooter";
import { SiteHeader } from "@/components/SiteHeader";
import { PrimaryMain } from "@/components/layout/PrimaryMain";
import { APP_BRAND_NAME } from "@/lib/product/brand-copy";
import { NOT_THERAPY_LINE } from "@/lib/trust-copy";
import {
  WEB_MARKETING_BODY,
  WEB_MARKETING_LEAD,
  WEB_MARKETING_MOBILE_NOTE,
  WEB_MARKETING_PROMISE,
} from "@/lib/site/web-marketing-copy";

export const metadata: Metadata = {
  title: `${APP_BRAND_NAME} — ${WEB_MARKETING_PROMISE}`,
  description: WEB_MARKETING_LEAD,
};

export default function HomePage() {
  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />
        <PrimaryMain className="mt-6">
          <p className="text-xs uppercase tracking-[0.2em] text-violet-200">{APP_BRAND_NAME}</p>
          <h1 className="mt-3 text-4xl font-semibold tracking-tight text-white sm:text-5xl">
            {WEB_MARKETING_PROMISE}
          </h1>
          <p className="mt-5 text-lg leading-relaxed text-zinc-200">{WEB_MARKETING_LEAD}</p>
          <p className="mt-4 text-sm leading-relaxed text-zinc-400">{WEB_MARKETING_BODY}</p>
          <p className="mt-4 text-sm leading-relaxed text-zinc-500">{WEB_MARKETING_MOBILE_NOTE}</p>
          <nav
            aria-label="Get started"
            className="mt-10 flex flex-wrap gap-4 text-sm font-medium"
          >
            <Link
              href="/beta"
              className="rounded-full bg-violet-600 px-5 py-2.5 text-white transition-colors hover:bg-violet-500 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-violet-400/60"
            >
              Beta &amp; download
            </Link>
            <Link
              href="/contact"
              className="rounded-full border border-white/15 px-5 py-2.5 text-zinc-200 transition-colors hover:border-white/25 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-violet-400/60"
            >
              Contact support
            </Link>
          </nav>
          <p className="mt-10 text-xs leading-relaxed text-zinc-600">{NOT_THERAPY_LINE}</p>
        </PrimaryMain>
        <SiteFooter className="mt-12" />
      </div>
    </div>
  );
}
