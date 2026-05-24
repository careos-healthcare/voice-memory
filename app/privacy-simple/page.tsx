import type { Metadata } from "next";
import Link from "next/link";

import { TrustPageShell, TrustSection } from "@/components/trust/TrustPageShell";
import {
  PRIVACY_SIMPLE_DESCRIPTION,
  PRIVACY_SIMPLE_EYEBROW,
  PRIVACY_SIMPLE_SECTIONS,
  PRIVACY_SIMPLE_TITLE,
  TESTER_ONBOARDING_LINKS,
} from "@/lib/tester-onboarding-copy";

export const metadata: Metadata = {
  title: "Privacy, simply — VoiceMemory",
  description: "A short privacy summary for VoiceMemory testers.",
};

export default function PrivacySimplePage() {
  return (
    <TrustPageShell
      eyebrow={PRIVACY_SIMPLE_EYEBROW}
      title={PRIVACY_SIMPLE_TITLE}
      description={PRIVACY_SIMPLE_DESCRIPTION}
    >
      {PRIVACY_SIMPLE_SECTIONS.map((section) => (
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
