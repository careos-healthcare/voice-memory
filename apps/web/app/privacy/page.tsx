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
    </TrustPageShell>
  );
}
