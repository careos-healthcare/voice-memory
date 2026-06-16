import { PRO_TIER } from "@/lib/entitlement/tiers";
import {
  PAYWALL_BODY,
  PAYWALL_HEADLINE,
  PAYWALL_POSITIONING,
} from "@/lib/archive/archive-disclosure-copy";

/** Core paywall positioning — shown after first proof, not before. */
export const VALUE_MOMENT_PAYWALL_COPY = {
  positioningLine: PAYWALL_POSITIONING,
  headline: PAYWALL_HEADLINE,
  body: PAYWALL_BODY,
  continuityLine:
    "A quick answer handles today. ArchiveMe tracks what keeps coming back across weeks and months.",
  cta: "Keep tracking my patterns",
  secondary: "Not now",
  trustLine:
    "No streaks. No pressure to journal daily. Just continuity when something meaningful changes.",
  proBullets: [
    "Ongoing belief history",
    "Full evidence timeline",
    "Belief changes over time",
    "Archive continuity and export",
  ],
} as const;

/** Pricing page alignment — value before paywall. */
export const VALUE_MOMENT_PRICING_COPY = {
  freeFeatures: [
    "First 5 reflections",
    "First working belief",
    "First archive view",
    "First discover view",
    "Voice recording and transcript on this device",
  ],
  proFeatures: [
    "Ongoing belief history",
    "Full evidence timeline",
    "Belief changes over time",
    "Archive continuity",
    "Export and private archive protection",
    "Deeper resurfacing when available",
  ],
  /** Kept in sync with Pro tier — £9.99/month */
  priceLabel: PRO_TIER.priceLabel,
} as const;

export const VALUE_MOMENT_PRO_PRICE_LABEL = "£9.99/month";
