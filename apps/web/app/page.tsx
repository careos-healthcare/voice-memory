import type { Metadata } from "next";
import Link from "next/link";

import { SiteFooter } from "@/components/SiteFooter";
import { SiteHeader } from "@/components/SiteHeader";
import { WaitlistForm } from "@/components/WaitlistForm";
import { PrimaryMain } from "@/components/layout/PrimaryMain";
import { MARKETING_SITE_URL } from "@/lib/site/marketing-site";
import { NOT_THERAPY_LINE } from "@/lib/trust-copy";

const title = "Thoughtprint — A private voice journal";
const description =
  "A private voice journal that remembers what you actually said. Free core, forever. Transcribed on your phone. Never metered.";

export const metadata: Metadata = {
  title,
  description,
  openGraph: {
    title,
    description,
    url: MARKETING_SITE_URL,
    siteName: "Thoughtprint",
    type: "website",
  },
};

const promises = [
  "Data Not Linked to You",
  "Private by Design",
  "No usage meters",
  "Free tier stays free",
];

const proofPoints = [
  "Transcribed on your phone.",
  "Every insight cites your own words.",
  "You can export or delete everything.",
];

export default function HomePage() {
  return (
    <div className="min-h-screen bg-zinc-950">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader />
        <PrimaryMain className="mt-6">
          <h1 className="mt-3 text-4xl font-semibold tracking-tight text-white sm:text-5xl">
            A private voice journal that remembers what you actually said.
          </h1>
          <p className="mt-5 text-lg leading-relaxed text-zinc-200">
            Free core, forever. Transcribed on your phone. Never metered.
          </p>
          <ul className="mt-8 space-y-3 text-base font-medium leading-relaxed text-white">
            {promises.map((point) => (
              <li key={point}>{point}</li>
            ))}
          </ul>
          <ul className="mt-8 space-y-3 text-sm leading-relaxed text-zinc-300">
            {proofPoints.map((point) => (
              <li key={point}>{point}</li>
            ))}
          </ul>
          <WaitlistForm />
          <section className="mt-12">
            <h2 className="text-lg font-medium text-white">Coming from another journal?</h2>
            <p className="mt-2 text-sm leading-relaxed text-zinc-400">
              Import your Day One or Apple Notes export.
            </p>
          </section>
          <p className="mt-10 text-sm">
            <Link href="/privacy" className="text-zinc-400 underline-offset-4 hover:text-zinc-200 hover:underline">
              Privacy
            </Link>
          </p>
          <p className="mt-6 text-xs leading-relaxed text-zinc-600">{NOT_THERAPY_LINE}</p>
        </PrimaryMain>
        <SiteFooter className="mt-12" />
      </div>
    </div>
  );
}
