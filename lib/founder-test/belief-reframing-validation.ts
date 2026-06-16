/**
 * Founder validation phase — Archive Belief mental model adoption.
 * No new intelligence, engines, or education features until this validates.
 */

export const ARCHIVE_BELIEF_ROADMAP_FREEZE = {
  title: "Current roadmap freeze",
  hypothesis:
    "Users return because they want to know whether the archive changed its view of them.",
  notHypothesis: "Users return because they want another insight.",
  shipped: [
    "Archive Belief card (Discover)",
    "Belief Change Timeline",
    "Evidence Accumulation Education (complete — no further work)",
  ],
  paused: [
    "Theory engines",
    "Blind spot engines",
    "New intelligence systems",
    "More evidence education",
    "Theory Tracker v2",
    "Notifications v2",
    "More dashboards",
  ],
} as const;

/** Success criteria in priority order — founder interviews + device metrics. */
export const ARCHIVE_BELIEF_SUCCESS_CRITERIA = [
  {
    id: "belief_language",
    rank: 1,
    title: "Belief language",
    question: "Does positioning land in how users describe the product?",
    passSignals: [
      "The archive thinks…",
      "My theory got stronger…",
      "ArchiveMe changed its mind…",
      "ArchiveMe believes…",
    ],
    failSignals: [
      "It gave me an insight.",
      "It found a pattern.",
    ],
    failMeaning: "If not, the positioning has not landed.",
  },
  {
    id: "archive_before_discover",
    rank: 2,
    title: "Archive before Discover (post-5)",
    question:
      "After reflection 5, do users open Archive before Discover on return visits?",
    metrics: [
      "post_five_first_surface_open",
      "archive_product_home_opened",
      "discover_opened",
      "archive_belief_viewed",
      "belief_timeline_viewed",
    ],
    want: "Open ArchiveMe → Archive first (what does my archive believe now?)",
    avoid: "Open ArchiveMe → Discover or record first every time",
    passMeaning: "Archive is the check-in destination; Discover is the change log.",
  },
  {
    id: "reflection_six",
    rank: 3,
    title: "Reflection 6 > reflection 5",
    question: "Does the archive feel alive after the fifth reflection?",
    atFive: "First working theory unlocked",
    atSix: "Belief or confidence evolves — user notices a meaningful change",
    fail: "Reflection 6 feels like another log entry — archive still feels static",
    deviceSignals: ["why_evidence_matters_seen", "belief_change_viewed", "belief_timeline_viewed"],
  },
] as const;

/** Build only if validation is positive — presentation of existing data, not new analysis. */
export const ARCHIVE_BELIEF_BUILD_IF_VALIDATED = {
  title: "Build only if validation is positive",
  feature: "Archive History / Belief History",
  reinforces: "I wonder what my archive thinks now.",
  presents: [
    "What the archive believed",
    "When it changed",
    "Why it changed",
    "What evidence caused the change",
  ],
  explicitlyNot: [
    "New intelligence",
    "New analysis engines",
  ],
} as const;

/** @deprecated Use ARCHIVE_BELIEF_* exports — kept for panel imports. */
export const BELIEF_REFRAMING_VALIDATION = {
  title: ARCHIVE_BELIEF_ROADMAP_FREEZE.title,
  hypothesis: ARCHIVE_BELIEF_ROADMAP_FREEZE.hypothesis,
  criteria: ARCHIVE_BELIEF_SUCCESS_CRITERIA,
} as const;
