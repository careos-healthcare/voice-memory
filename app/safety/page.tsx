import type { Metadata } from "next";

import { TrustPageShell, TrustSection } from "@/components/trust/TrustPageShell";
import { CRISIS_DISCLAIMER, SAFETY_SECTIONS } from "@/lib/trust-copy";

export const metadata: Metadata = {
  title: "Safety — ArchiveMe",
  description: "ArchiveMe is not therapy, not a diagnosis, and not crisis support. Crisis resources included.",
};

export default function SafetyPage() {
  return (
    <TrustPageShell
      eyebrow="Trust"
      title="Safety & emotional boundaries"
      description="ArchiveMe helps you notice patterns in your own words. It is not therapy, not crisis support, and never pressures you to keep recording."
    >
      <section className="rounded-2xl border border-amber-500/20 bg-amber-950/20 p-5">
        <h2 className="text-base font-semibold text-amber-100">If you need urgent help</h2>
        <p className="mt-2 text-sm leading-relaxed text-amber-50">{CRISIS_DISCLAIMER}</p>
      </section>
      {SAFETY_SECTIONS.map((section) => (
        <TrustSection key={section.title} title={section.title} body={section.body} />
      ))}
    </TrustPageShell>
  );
}
