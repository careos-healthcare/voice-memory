import type { Metadata } from "next";

import { TrustPageShell, TrustSection } from "@/components/trust/TrustPageShell";
import { TERMS_SECTIONS } from "@/lib/trust-copy";

import { APP_DESCRIPTION_SHORT } from "@/lib/product-copy";

export const metadata: Metadata = {
  title: "Terms — ArchiveMe",
  description: `Terms of use for ArchiveMe — ${APP_DESCRIPTION_SHORT}`,
};

export default function TermsPage() {
  return (
    <TrustPageShell
      eyebrow="Legal"
      title="Terms of use"
      description="By using ArchiveMe you agree to these terms. Last updated for launch readiness."
    >
      {TERMS_SECTIONS.map((section) => (
        <TrustSection key={section.title} title={section.title} body={section.body} />
      ))}
    </TrustPageShell>
  );
}
