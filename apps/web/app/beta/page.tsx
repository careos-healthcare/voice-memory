import type { Metadata } from "next";
import Link from "next/link";

import { TrustPageShell, TrustSection } from "@/components/trust/TrustPageShell";
import {
  WEB_BETA_DESCRIPTION,
  WEB_BETA_TITLE,
  WEB_MARKETING_PROMISE,
} from "@/lib/site/web-marketing-copy";

export const metadata: Metadata = {
  title: `${WEB_BETA_TITLE} — ArchiveMe`,
  description: WEB_BETA_DESCRIPTION,
};

export default function BetaPage() {
  return (
    <TrustPageShell
      eyebrow="ArchiveMe"
      title={WEB_BETA_TITLE}
      description={WEB_BETA_DESCRIPTION}
    >
      <TrustSection
        title={WEB_MARKETING_PROMISE}
        body="The consumer app runs on iOS and Android. Install from your platform store when invited to the beta, or follow tester onboarding for setup notes."
      />
      <TrustSection
        title="Tester onboarding"
        body="Early testers can read the welcome guide for privacy expectations, export, and how memory builds slowly — without streaks or performance pressure."
      />
      <nav className="flex flex-wrap gap-4 pt-2 text-sm">
        <Link href="/welcome" className="text-violet-300 hover:text-violet-200">
          Welcome guide →
        </Link>
        <Link href="/contact" className="text-violet-300 hover:text-violet-200">
          Contact →
        </Link>
      </nav>
    </TrustPageShell>
  );
}
