import type { Metadata } from "next";

import { TrustPageShell, TrustSection } from "@/components/trust/TrustPageShell";
import { TERMS_SECTIONS } from "@/lib/trust-copy";

export const metadata: Metadata = {
  title: "Terms — VoiceMemory",
  description: "Terms of use for VoiceMemory private memory intelligence.",
};

export default function TermsPage() {
  return (
    <TrustPageShell
      eyebrow="Legal"
      title="Terms of use"
      description="By using VoiceMemory you agree to these terms. Last updated for launch readiness."
    >
      {TERMS_SECTIONS.map((section) => (
        <TrustSection key={section.title} title={section.title} body={section.body} />
      ))}
    </TrustPageShell>
  );
}
