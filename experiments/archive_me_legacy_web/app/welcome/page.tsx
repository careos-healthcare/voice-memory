import type { Metadata } from "next";
import Link from "next/link";

import { TrustPageShell, TrustSection } from "@/components/trust/TrustPageShell";
import {
  TESTER_ONBOARDING_LINKS,
  WELCOME_DESCRIPTION,
  WELCOME_EYEBROW,
  WELCOME_SECTIONS,
  WELCOME_TITLE,
} from "@/lib/tester-onboarding-copy";

export const metadata: Metadata = {
  title: "Welcome — ArchiveMe",
  description: "A calm welcome for early testers. Private moments, optional backup, no pressure.",
};

export default function WelcomePage() {
  return (
    <TrustPageShell
      eyebrow={WELCOME_EYEBROW}
      title={WELCOME_TITLE}
      description={WELCOME_DESCRIPTION}
    >
      {WELCOME_SECTIONS.map((section) => (
        <TrustSection key={section.title} title={section.title} body={section.body} />
      ))}
      <nav className="flex flex-wrap gap-4 pt-2 text-sm">
        {TESTER_ONBOARDING_LINKS.map((link) => (
          <Link key={link.href} href={link.href} className="text-violet-300 hover:text-violet-200">
            {link.label} →
          </Link>
        ))}
      </nav>
    </TrustPageShell>
  );
}
