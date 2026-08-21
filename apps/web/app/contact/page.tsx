import type { Metadata } from "next";

import { TrustPageShell, TrustSection } from "@/components/trust/TrustPageShell";
import {
  CONTACT_EMAIL,
  DATA_DELETION_SUMMARY,
  DATA_EXPORT_SUMMARY,
} from "@/lib/trust-copy";

export const metadata: Metadata = {
  title: "Contact — ArchiveMe",
  description: "Contact ArchiveMe for privacy, safety, and product questions.",
};

export default function ContactPage() {
  return (
    <TrustPageShell
      eyebrow="Trust"
      title="Contact"
      description="Questions about privacy, data export, deletion, or safety — we read every message."
    >
      <section className="rounded-2xl border border-violet-400/20 bg-violet-500/10 p-5">
        <h2 className="text-base font-semibold text-white">Email</h2>
        <p className="mt-2 text-sm text-zinc-300">
          <a
            href={`mailto:${CONTACT_EMAIL}`}
            className="font-medium text-violet-300 hover:text-violet-200"
          >
            {CONTACT_EMAIL}
          </a>
        </p>
        <p className="mt-3 text-xs leading-relaxed text-zinc-500">
          For data deletion requests, include the browser or device you used and approximate
          dates. We cannot retrieve local-only data from our servers — contact us for account
          backup questions or use the mobile app settings to delete on-device data immediately.
        </p>
      </section>
      <TrustSection title="Export" body={DATA_EXPORT_SUMMARY} />
      <TrustSection title="Deletion" body={DATA_DELETION_SUMMARY} />
      <TrustSection
        title="Not for emergencies"
        body="Do not use this email for crisis support. If you may be in danger, see our Safety page for crisis lines."
      />
    </TrustPageShell>
  );
}
