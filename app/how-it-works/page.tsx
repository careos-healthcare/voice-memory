import type { Metadata } from "next";
import Link from "next/link";

import { TrustPageShell, TrustSection } from "@/components/trust/TrustPageShell";
import {
  HOW_IT_WORKS_DESCRIPTION,
  HOW_IT_WORKS_EYEBROW,
  HOW_IT_WORKS_SECTIONS,
  HOW_IT_WORKS_TITLE,
  TESTER_ONBOARDING_LINKS,
} from "@/lib/tester-onboarding-copy";

export const metadata: Metadata = {
  title: "How it works — VoiceMemory",
  description: "How VoiceMemory works for early testers: local reflections, optional resurfacing, optional backup.",
};

export default function HowItWorksPage() {
  return (
    <TrustPageShell
      eyebrow={HOW_IT_WORKS_EYEBROW}
      title={HOW_IT_WORKS_TITLE}
      description={HOW_IT_WORKS_DESCRIPTION}
    >
      {HOW_IT_WORKS_SECTIONS.map((section) => (
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
