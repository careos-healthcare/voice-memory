import type { Metadata } from "next";

import { TrustPageShell, TrustSection } from "@/components/trust/TrustPageShell";
import { PRIVACY_SECTIONS } from "@/lib/trust-copy";

export const metadata: Metadata = {
  title: "Privacy — VoiceMemory",
  description: "How VoiceMemory handles your data: local-first storage, OpenAI processing, export and deletion.",
};

export default function PrivacyPage() {
  return (
    <TrustPageShell
      eyebrow="Trust"
      title="Privacy"
      description="Your reflections stay on this device by default. Cloud processing is limited to transcription and organizing what you said when you record."
    >
      {PRIVACY_SECTIONS.map((section) => (
        <TrustSection key={section.title} title={section.title} body={section.body} />
      ))}
    </TrustPageShell>
  );
}
