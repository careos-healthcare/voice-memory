import { LANDING_3_DAY_CHALLENGE } from "@/lib/product/landing-three-day-challenge-copy";
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
  continuityLine: LANDING_3_DAY_CHALLENGE.chatGptDifferentiation,
  cta: "Keep the full timeline",
  secondary: "Not now",
  trustLine: LANDING_3_DAY_CHALLENGE.subheadline,
  proBullets: [
    "Full pattern timeline",
    "Correction history",
    "Changing current weight",
    "Longer evidence trail",
  ],
} as const;

/** Pricing page alignment — value before paywall. */
export const VALUE_MOMENT_PRICING_COPY = {
  pageLead: LANDING_3_DAY_CHALLENGE.pricing.pageLead,
  proReason: LANDING_3_DAY_CHALLENGE.proSection.paidReason,
  freeFeatures: [
    "First proof from your saves",
    "First working belief",
    "First archive view",
    "First discover view",
    "Voice recording and transcript on this device",
  ],
  proFeatures: [
    "Full pattern timeline",
    "Correction history",
    "Changing current weight",
    "Longer evidence trail",
    "Monthly private report when eligible",
    "Backup and continuity when you sign in",
  ],
  /** Displayed only when resolved from live billing metadata. */
  priceLabel: PRO_TIER.priceLabel,
} as const;
