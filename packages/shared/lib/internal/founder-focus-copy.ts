/** Founder mode copy — complexity reduction v2. */

export const FOUNDER_MODE_PREAMBLE = {
  headline: "The biggest risk is not missing features.",
  body: "The biggest risk is failing to create:",
  priorities: [
    "First archive belief",
    "Archive curiosity",
    "Return behavior",
    "Paid conversion",
  ],
} as const;

export const NORTH_STAR_PAGE = {
  eyebrow: "North star",
  title: "Company health",
  subheadline: "Five metrics only — read in under a minute.",
} as const;

export const FOUNDER_ARCHIVE_PAGE = {
  eyebrow: "Founder dashboard",
  title: "Archive",
  subheadline: "Activation, return, and conversion — nothing else on this surface.",
} as const;

export const NORTH_STAR_METRIC_COPY = {
  activation: {
    title: "Activation Rate",
    subtitle: "Reached first belief",
  },
  return: {
    title: "Archive Return Rate",
    subtitle: "Returned after archive changed",
  },
  curiosity: {
    title: "Archive Curiosity Rate",
    subtitle: "Wanted to check archive",
  },
  conversion: {
    title: "Subscription Conversion",
    subtitle: "Paid after value",
  },
  attachment: {
    title: "Archive Attachment",
    subtitle: "Would miss archive",
  },
} as const;

export const FOUNDER_DASHBOARD_TAB_COPY = {
  activation: {
    label: "Activation",
    headline: "First belief is the gate",
  },
  return: {
    label: "Return",
    headline: "Archive must change before users come back",
  },
  conversion: {
    label: "Conversion",
    headline: "Pay only after archive value is felt",
  },
} as const;

export const FOUNDER_INTERNAL_NAV = {
  commandCenter: { href: "/internal", label: "Command center" },
  launch: { href: "/internal/launch", label: "Launch" },
} as const;
