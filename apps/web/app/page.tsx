import type { Metadata } from "next";
import Link from "next/link";

import { Roadmap } from "@/components/Roadmap";
import { SiteFooter } from "@/components/SiteFooter";
import { SiteHeader } from "@/components/SiteHeader";
import { WaitlistForm } from "@/components/WaitlistForm";
import { PrimaryMain } from "@/components/layout/PrimaryMain";
import { MARKETING_SITE_URL } from "@/lib/site/marketing-site";
import { NOT_THERAPY_LINE } from "@/lib/trust-copy";

const title = "Thoughtprint — A private voice journal";
const description =
  "A private voice journal that remembers what you actually said. Free core, forever. Transcribed on your phone by default. Never metered.";

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
  "We can't see your journal. Nothing is linked to your identity.",
  "Private by Design",
  "No usage meters",
  "Free tier stays free",
];

const features = [
  "Live cross-device sync",
  "Apple Voice Memos import",
  "Add a mood or a place to any moment",
];

export default function HomePage() {
  return (
    <div className="min-h-screen bg-[#FDFBF7] text-[#172033]">
      <div className="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
        <SiteHeader tone="cream" />
        <PrimaryMain className="mt-6">
          <h1 className="mt-3 font-serif text-4xl font-semibold tracking-tight text-[#172033] sm:text-5xl">
            A private voice journal that remembers what you actually said.
          </h1>
          <WaitlistForm />
          <p className="mt-3 text-sm leading-relaxed text-[#4B5568]">
            Core is free forever. Pro (optional) is about $7/month.
          </p>
          <p className="mt-5 text-lg leading-relaxed text-[#3F4757]">
            Free core, forever. Transcribed on your phone by default. Never metered.
          </p>
          <ul className="mt-8 space-y-3 text-base font-medium leading-relaxed text-[#172033]">
            {promises.map((point) => (
              <li key={point}>{point}</li>
            ))}
          </ul>
          <ul className="mt-8 space-y-3 text-base leading-relaxed text-[#3F4757]">
            {features.map((point) => (
              <li key={point}>{point}</li>
            ))}
          </ul>
          <Roadmap />
          <section className="mt-12" aria-labelledby="import-heading">
            <h2 id="import-heading" className="font-serif text-lg font-medium text-[#172033]">
              Coming from another journal?
            </h2>
            <p className="mt-2 text-sm leading-relaxed text-[#4B5568]">
              <a href="#import-day-one" className="text-[#2563EB] underline-offset-4 hover:underline">
                Export from Day One
              </a>
              {" · "}
              <a href="#import-apple-notes" className="text-[#2563EB] underline-offset-4 hover:underline">
                Export from Apple Notes
              </a>
            </p>
            <div id="import-day-one" className="mt-6 scroll-mt-6">
              <h3 className="font-serif text-base font-medium text-[#172033]">Day One</h3>
              <p className="mt-1 text-sm leading-relaxed text-[#4B5568]">
                In Day One, open Settings, then Import/Export, and export your journal as JSON.
                Thoughtprint reads that file.
              </p>
            </div>
            <div id="import-apple-notes" className="mt-4 scroll-mt-6">
              <h3 className="font-serif text-base font-medium text-[#172033]">Apple Notes</h3>
              <p className="mt-1 text-sm leading-relaxed text-[#4B5568]">
                Export the notes as JSON or CSV. Thoughtprint reads Apple Notes JSON and CSV exports.
              </p>
            </div>
          </section>
          <p className="mt-10 text-sm">
            <Link href="/privacy" className="text-[#2563EB] underline-offset-4 hover:underline">
              Privacy
            </Link>
          </p>
          <p className="mt-6 text-xs leading-relaxed text-[#667085]">{NOT_THERAPY_LINE}</p>
        </PrimaryMain>
        <SiteFooter tone="cream" className="mt-12" />
      </div>
    </div>
  );
}
