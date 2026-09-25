import type { Metadata } from "next";

import { TrustPageShell, TrustSection } from "@/components/trust/TrustPageShell";
import { PRIVACY_SECTIONS } from "@/lib/trust-copy";

export const metadata: Metadata = {
  title: "Privacy — Thoughtprint",
  description: "How Thoughtprint handles your data: local-first storage, AI transcription and analysis, export and deletion.",
};

export default function PrivacyPage() {
  return (
    <TrustPageShell
      eyebrow="Trust"
      title="Privacy"
      description="Your archive is private by default. Thoughtprint only sends data for transcription, analysis, sync, or account features when those features are used."
    >
      {PRIVACY_SECTIONS.map((section) => (
        <TrustSection key={section.title} title={section.title} body={section.body} />
      ))}
      <TrustSection
        title="Waitlist"
        body="We collect only your email address and the time you joined. We use that to send a single launch announcement. Resend delivers the email and Neon stores the address. Every email includes a one-click unsubscribe link."
      />
    </TrustPageShell>
  );
}
