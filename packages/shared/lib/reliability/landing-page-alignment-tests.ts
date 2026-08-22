import { readFileSync } from "node:fs";
import { join } from "node:path";

import {
  LANDING_3_DAY_BANNED_PHRASES,
  LANDING_3_DAY_CHALLENGE,
  landingVisibleStrings,
} from "@/lib/product/landing-three-day-challenge-copy";

const REQUIRED_LANDING_COPY = {
  hero: "See what keeps returning",
  subheadline: "No daily journal required.",
  chatGptDifferentiation:
    "ChatGPT can answer a conversation. ArchiveMe shows the timeline behind the pattern.",
  proPaidReason: "Pro keeps the full timeline as it grows.",
} as const;

const THERAPY_PROMOTION = /\b(therapy|diagnosis|medical treatment)\b/i;
const THERAPY_DISCLAIMER = /not therapy|not a diagnos|not medical advice/i;

export function runLandingPageAlignmentTests(): { failures: string[] } {
  const failures: string[] = [];
  const root = process.cwd();

  const check = (name: string, fn: () => void) => {
    try {
      fn();
    } catch (err) {
      failures.push(`${name}: ${err instanceof Error ? err.message : String(err)}`);
    }
  };

  check("landing hero matches alignment v1", () => {
    if (LANDING_3_DAY_CHALLENGE.hero !== REQUIRED_LANDING_COPY.hero) {
      throw new Error(`expected hero "${REQUIRED_LANDING_COPY.hero}"`);
    }
  });

  check("landing subheadline matches alignment v1", () => {
    if (LANDING_3_DAY_CHALLENGE.subheadline !== REQUIRED_LANDING_COPY.subheadline) {
      throw new Error(`expected subheadline "${REQUIRED_LANDING_COPY.subheadline}"`);
    }
  });

  check("landing ChatGPT differentiation matches alignment v1", () => {
    if (
      LANDING_3_DAY_CHALLENGE.chatGptDifferentiation !==
      REQUIRED_LANDING_COPY.chatGptDifferentiation
    ) {
      throw new Error("ChatGPT differentiation drifted from alignment v1");
    }
  });

  check("landing Pro paid reason matches alignment v1", () => {
    if (LANDING_3_DAY_CHALLENGE.proSection.paidReason !== REQUIRED_LANDING_COPY.proPaidReason) {
      throw new Error(`expected pro line "${REQUIRED_LANDING_COPY.proPaidReason}"`);
    }
  });

  check("landing how-it-works steps match alignment v1", () => {
    const titles = LANDING_3_DAY_CHALLENGE.steps.map((step) => step.title);
    const expected = [
      "Save one small moment",
      "Come back when something stands out",
      "See what returned",
      "Correct what is not relevant",
      "Keep the full timeline with Pro",
    ];
    if (JSON.stringify(titles) !== JSON.stringify(expected)) {
      throw new Error(`expected steps ${expected.join(" | ")}`);
    }
  });

  check("landing visible strings avoid banned therapy promotion", () => {
    const blob = landingVisibleStrings().join(" ");
    if (THERAPY_PROMOTION.test(blob) && !THERAPY_DISCLAIMER.test(blob)) {
      throw new Error("landing copy promotes therapy/medical without disclaimer");
    }
  });

  check("landing visible strings avoid banned live claims", () => {
    const blob = landingVisibleStrings().join(" ").toLowerCase();
    for (const phrase of LANDING_3_DAY_BANNED_PHRASES) {
      if (phrase === "therapy") continue;
      if (blob.includes(phrase)) {
        throw new Error(`landing copy contains banned phrase: ${phrase}`);
      }
    }
  });

  check("homepage renders alignment copy markers", () => {
    const page = readFileSync(join(root, "app/page.tsx"), "utf8");
    const component = readFileSync(
      join(root, "components/landing/ThreeDayProofChallengeLanding.tsx"),
      "utf8",
    );
    const landingCopy = readFileSync(
      join(root, "lib/product/landing-three-day-challenge-copy.ts"),
      "utf8",
    );
    const blob = `${page}\n${component}\n${landingCopy}`;
    for (const token of Object.values(REQUIRED_LANDING_COPY)) {
      if (!blob.includes(token)) {
        throw new Error(`landing wiring missing ${token}`);
      }
    }
    if (!page.includes("PRODUCT_HERO.promise")) {
      throw new Error("homepage hero must render PRODUCT_HERO.promise");
    }
    if (!page.includes("POSITIONING_EYEBROW") && !page.includes("PRODUCT_HERO.eyebrow")) {
      throw new Error("homepage hero must render subheadline eyebrow");
    }
    if (!page.includes("LANDING_3_DAY_CHALLENGE.steps.map")) {
      throw new Error("homepage must render how-it-works steps from landing copy");
    }
    if (!blob.includes("landing-pro-paid-reason")) {
      throw new Error("homepage missing Pro paid reason marker");
    }
    if (!blob.includes("landing-chatgpt-differentiation")) {
      throw new Error("homepage missing ChatGPT differentiation marker");
    }
  });

  check("landing copy does not add fake testimonials", () => {
    const blob = landingVisibleStrings().join(" ");
    if (/verified user|★★★★★|testimonial/i.test(blob)) {
      throw new Error("landing copy includes testimonial-style social proof");
    }
  });

  check("how-it-works page uses landing alignment copy", () => {
    const howItWorks = readFileSync(join(root, "lib/tester-onboarding-copy.ts"), "utf8");
    const page = readFileSync(join(root, "app/how-it-works/page.tsx"), "utf8");
    const blob = `${howItWorks}\n${page}`;
    if (!blob.includes("LANDING_3_DAY_CHALLENGE.subheadline")) {
      throw new Error("how-it-works must wire subheadline from landing copy");
    }
    if (!blob.includes("LANDING_3_DAY_CHALLENGE.steps")) {
      throw new Error("how-it-works must wire steps from landing copy");
    }
    if (!blob.includes("LANDING_3_DAY_CHALLENGE.chatGptDifferentiation")) {
      throw new Error("how-it-works must wire ChatGPT differentiation from landing copy");
    }
  });

  check("pricing page uses landing paid positioning", () => {
    const pricingShell = readFileSync(
      join(root, "components/pricing/PricingStaticShell.tsx"),
      "utf8",
    );
    const pricingClient = readFileSync(join(root, "app/pricing/PricingPageClient.tsx"), "utf8");
    const pricingCopy = readFileSync(
      join(root, "lib/billing/value-moment-paywall-copy.ts"),
      "utf8",
    );
    const blob = `${pricingShell}\n${pricingClient}\n${pricingCopy}`;
    if (!blob.includes("LANDING_3_DAY_CHALLENGE.pricing.pageLead")) {
      throw new Error("pricing must wire free/pro positioning from landing copy");
    }
    if (!blob.includes("LANDING_3_DAY_CHALLENGE.proSection.paidReason")) {
      throw new Error("pricing must wire Pro paid reason from landing copy");
    }
    if (!blob.includes("LANDING_3_DAY_CHALLENGE.chatGptDifferentiation")) {
      throw new Error("pricing must wire ChatGPT differentiation from landing copy");
    }
  });

  return { failures };
}
