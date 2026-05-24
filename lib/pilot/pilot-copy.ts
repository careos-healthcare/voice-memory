/** Pilot pricing and page copy — archival continuity framing only. */

export const PILOT_PAGE_COPY = {
  eyebrow: "Archive continuity",
  title: "A small, careful pilot",
  description:
    "VoiceMemory is being developed with a small group of people who want long-term archive protection — not fast growth.",
  sections: [
    {
      title: "What support covers",
      body: "Encrypted backup, archive continuity across devices, and long-term preservation of your reflections. Payment supports sustainable development of those protections.",
    },
    {
      title: "How this works",
      body: "This is being developed carefully with a small group of people. The goal is long-term trust, not fast growth. There is no automatic checkout yet — founder approval only.",
    },
    {
      title: "Why support matters",
      body: "Support helps keep encrypted backup and archive continuity sustainable while the archive stays private and portable on your device.",
    },
  ],
  pricingLink: "Read how pricing is framed",
  accountLink: "Account & encrypted backup",
} as const;

export const PILOT_PRICING_FRAMING = {
  headline: "Archive continuity support",
  body: "Payment is framed only as archive protection — encrypted backup, preservation, and careful long-term development. Not more intelligence, not productivity tools.",
  bullets: [
    "Encrypted backup and recovery across devices",
    "Long-term archive preservation",
    "Sustainable, careful development",
    "Portable exports you already own",
  ],
  footer: "No checkout yet. Founder-led approval for a tiny pilot (10–20 people).",
} as const;

export const PILOT_FORBIDDEN = [
  "unlock features",
  "premium intelligence",
  "upgrade your growth",
  "ai insights",
  "productivity",
  "waitlist",
  "exclusive access",
  "limited spots",
  "act now",
  "don't miss",
  "startup",
  "scale fast",
  "growth hack",
  "fomo",
  "countdown",
] as const;

export const PILOT_SUPPRESSED_COPY = {
  title: "Still observing",
  body: "VoiceMemory is still being developed carefully. Your archive stays private on this device until continuity support is offered thoughtfully.",
} as const;

export function passesPilotCopy(text: string): boolean {
  const lower = text.toLowerCase();
  return !PILOT_FORBIDDEN.some((phrase) => lower.includes(phrase));
}

export function pilotFounderLabelText(label: import("@/types/pilot-system").PilotFounderLabel): string {
  const labels: Record<import("@/types/pilot-system").PilotFounderLabel, string> = {
    highly_attached: "Highly attached",
    trust_sensitive: "Trust-sensitive",
    likely_early_supporter: "Likely early supporter",
    not_ready: "Not ready",
  };
  return labels[label];
}

export function pilotAccessStatusLabel(status: import("@/types/pilot-system").PilotAccessStatus): string {
  const labels: Record<import("@/types/pilot-system").PilotAccessStatus, string> = {
    approved: "Approved",
    invited: "Invited",
    observing: "Observing",
    declined: "Declined",
  };
  return labels[status];
}
