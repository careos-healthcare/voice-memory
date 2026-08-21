"use client";

import { useEffect, useState } from "react";
import Link from "next/link";

import { SiteFooter } from "@/components/SiteFooter";
import { SiteHeader } from "@/components/SiteHeader";
import { MotionPageTitle } from "@/archived-components/_archived/motion/MotionPage";
import {
  PILOT_PAGE_COPY,
  PILOT_PRICING_FRAMING,
  PILOT_SUPPRESSED_COPY,
} from "@/lib/pilot/pilot-copy";
import {
  trackPilotPageViewed,
  trackPilotPaymentAsked,
  trackPilotPricingOpened,
} from "@/lib/pilot/pilot-interest";
import { shouldShowPilotExposure } from "@/lib/pilot/pilot-restraint";

export default function PilotPage() {
  const [allowed, setAllowed] = useState<boolean | null>(null);

  useEffect(() => {
    void shouldShowPilotExposure().then((value) => {
      setAllowed(value);
      if (value) trackPilotPageViewed();
    });
  }, []);

  if (allowed === null) {
    return (
      <div className="min-h-screen bg-zinc-950">
        <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
          <SiteHeader />
          <MotionPageTitle title="Pilot" />
          <p className="mt-16 text-sm text-zinc-500">Loading…</p>
        </div>
      </div>
    );
  }

  if (!allowed) {
    return (
      <div className="min-h-screen bg-zinc-950">
        <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
          <SiteHeader />
          <MotionPageTitle title={PILOT_SUPPRESSED_COPY.title} />
          <p className="mt-16 text-sm leading-[1.75] text-zinc-500">{PILOT_SUPPRESSED_COPY.body}</p>
          <SiteFooter className="mt-16" />
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-24 sm:px-6">
        <SiteHeader />
        <p className="mt-2 text-xs uppercase tracking-[0.2em] text-violet-300/80">{PILOT_PAGE_COPY.eyebrow}</p>
        <MotionPageTitle title={PILOT_PAGE_COPY.title} />
        <p className="mt-4 text-sm leading-[1.75] text-zinc-400">{PILOT_PAGE_COPY.description}</p>

        <div className="mt-16 space-y-10">
          {PILOT_PAGE_COPY.sections.map((section) => (
            <section key={section.title}>
              <h2 className="text-base font-normal text-zinc-200">{section.title}</h2>
              <p className="mt-2 text-sm leading-[1.75] text-zinc-500">{section.body}</p>
            </section>
          ))}

          <section className="rounded-2xl border border-white/[0.06] bg-zinc-900/40 p-5">
            <h2 className="text-base font-normal text-zinc-200">{PILOT_PRICING_FRAMING.headline}</h2>
            <p className="mt-2 text-sm leading-[1.75] text-zinc-500">{PILOT_PRICING_FRAMING.body}</p>
            <ul className="mt-4 space-y-2 text-sm text-zinc-500">
              {PILOT_PRICING_FRAMING.bullets.map((bullet) => (
                <li key={bullet}>· {bullet}</li>
              ))}
            </ul>
            <p className="mt-4 text-xs text-zinc-600">{PILOT_PRICING_FRAMING.footer}</p>
          </section>

          <nav className="flex flex-wrap gap-4 text-sm">
            <Link
              href="/pricing?from=pilot"
              className="text-violet-300 hover:text-violet-200"
              onClick={() => trackPilotPricingOpened()}
            >
              {PILOT_PAGE_COPY.pricingLink} →
            </Link>
            <Link href="/account" className="text-zinc-500 hover:text-zinc-300">
              {PILOT_PAGE_COPY.accountLink} →
            </Link>
            <button
              type="button"
              className="text-zinc-500 hover:text-zinc-300"
              onClick={() => trackPilotPaymentAsked("pilot_page")}
            >
              Ask about payment
            </button>
          </nav>
        </div>

        <SiteFooter className="mt-16" />
      </div>
    </div>
  );
}
