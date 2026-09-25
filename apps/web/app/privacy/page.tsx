import type { Metadata } from "next";

import { TrustPageShell, TrustSection } from "@/components/trust/TrustPageShell";
import {
  CLOUD_AI_CONSENT_LINE,
  CLOUD_AI_CONSENT_SUPPORT,
  PRIVACY_SECTIONS,
} from "@/lib/trust-copy";

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
      <section className="rounded-2xl border border-white/10 bg-white/[0.02] p-5">
        <h2 className="text-base font-semibold text-white">Privacy and security</h2>
        <p className="mt-2 text-base font-semibold leading-relaxed text-white">
          {CLOUD_AI_CONSENT_LINE}
        </p>
        <p className="mt-2 text-sm leading-relaxed text-muted">{CLOUD_AI_CONSENT_SUPPORT}</p>
      </section>
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
