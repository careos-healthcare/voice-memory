/**
 * Founder validation — prove Archive is the product before Archive History / Belief History.
 * No new analysis engines until these four questions move.
 */

export const ARCHIVE_AS_PRODUCT_MAIN_QUESTION =
  "Do users now think Archive is the product — not a journal, insight app, or reflection tool?";

export const ARCHIVE_AS_PRODUCT_ROADMAP_FREEZE = {
  hypothesis:
    "People care whether the archive changed its view of them — not whether they got another insight.",
  buildOnlyIfValidated: [
    "Archive History",
    "Belief History",
    "Archive Evolution replay",
  ],
  explicitlyNot: [
    "New analysis engines",
    "Theory v2",
    "Notifications v2",
    "More dashboards",
  ],
} as const;

export const ARCHIVE_AS_PRODUCT_CRITERIA = [
  {
    id: "user_language",
    rank: 1,
    title: "User language",
    question:
      'When users describe ArchiveMe, do they say "my archive", "what it believes", "how it changed — or still "journal", "AI insights", "reflection app"?',
    passSignals: [
      "my archive",
      "what it believes",
      "how it changed",
      "the archive thinks",
      "changed its mind",
      "evolving archive",
    ],
    failSignals: [
      "journal",
      "AI insights",
      "reflection app",
      "insight tool",
      "pattern app",
      "voice notes",
    ],
    passThresholdPercent: 50,
    passMeaning: "Users describe an evolving archive, not an insight feed.",
    failMeaning: "Users still frame ArchiveMe as journal or insight tooling — positioning not landed.",
  },
  {
    id: "archive_before_discover",
    rank: 2,
    title: "Archive before Discover (post-5)",
    question:
      "After reflection 5, do users open Archive before Discover on return visits?",
    passThresholdPercent: 40,
    passMeaning: "Archive is the check-in destination; Discover is the change log.",
    failMeaning: "Users still open Discover (or record) first — archive is not the home yet.",
  },
  {
    id: "reflection_six_value",
    rank: 3,
    title: "Reflection 6 > reflection 5",
    question:
      'Does reflection 6 feel like "the archive updated its understanding" — not just another log entry?',
    passThresholdPercent: 40,
    passMeaning: "The archive feels alive after the fifth reflection unlocks a belief.",
    failMeaning: "Reflection 6 still feels static — users do not notice belief movement.",
  },
  {
    id: "voluntary_archive_return",
    rank: 4,
    title: "Voluntary Archive return",
    question:
      'Do users return on their own to check "what does my archive believe now?" — not because of notifications or reminders?',
    passThresholdPercent: 30,
    passMeaning: "Users voluntarily treat Archive as something worth checking.",
    failMeaning: "Returns are prompt-driven — archive is not yet the pull.",
  },
] as const;

export const ARCHIVE_AS_PRODUCT_INTERVIEW_QUESTIONS = [
  'How would you describe ArchiveMe to a friend in one sentence? (Code: archive / insight / journal / mixed)',
  "After your fifth reflection, what did you open first on your next visit — Archive or Discover?",
  "After your sixth reflection, did it feel like the archive updated its view — or like another entry?",
  "Did you come back on your own to see what your archive believes now — without a notification or reminder?",
] as const;

export function classifyProductDescriptionVerbatim(
  verbatim: string,
): import("@/types/archive-as-product-validation").ProductDescriptionCategory {
  const t = verbatim.trim().toLowerCase();
  if (!t) return "unclear";

  const archive =
    /\b(my archive|the archive|what it believes|how it changed|archive believes|changed its (mind|view)|evolving (archive|belief)|belief history|working belief)\b/i;
  const insight =
    /\b(ai insight|insights app|insight tool|pattern app|blind spot app|gave me an insight|found a pattern)\b/i;
  const journal =
    /\b(journal|diary|reflection app|voice journal|voice notes|logging|record thoughts)\b/i;

  const a = archive.test(t);
  const i = insight.test(t);
  const j = journal.test(t);

  if (a && !i && !j) return "archive_model";
  if ((i || j) && !a) return i ? "insight_tool" : "journal_mode";
  if (a && (i || j)) return "mixed";
  return "unclear";
}
