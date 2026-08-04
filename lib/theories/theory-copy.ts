import { THEORIES_PAGE_ARCHIVE_BELIEFS } from "@/lib/archive/archive-belief-copy";

export const THEORY_PAGE = {
  eyebrow: THEORIES_PAGE_ARCHIVE_BELIEFS.eyebrow,
  title: THEORIES_PAGE_ARCHIVE_BELIEFS.title,
  lead: THEORIES_PAGE_ARCHIVE_BELIEFS.lead,
  disclaimer:
    "Not advice, not clinical labeling, and not a fixed identity label — only hypotheses tied to your saved moments.",
  activeTitle: "Active",
  strengtheningTitle: "Strengthening",
  weakeningTitle: "Weakening",
  resolvedTitle: "Resolved",
  retiredTitle: "Retired",
  whatChangedLabel: "What changed?",
  supportingLabel: "Supporting moments",
  contradictingLabel: "Contradicting moments",
  confidenceLabel: "Confidence",
  emptyTitle: "No working theories yet",
  emptyBody:
    "After a few moments, ArchiveMe can surface falsifiable hypotheses from patterns already in your archive.",
} as const;

export const THEORY_FEEDBACK_LABELS: Record<
  import("@/types/theory").TheoryFeedbackReaction,
  string
> = {
  feels_true: "Feels true",
  partly_true: "Partly true",
  not_true: "Not true",
  too_obvious: "Too obvious",
  surprising: "Surprising",
};

export const FORBIDDEN_THEORY_OUTPUT =
  /\b(diagnos|disorder|narciss|toxic|therapy|treatment|trauma|clinical|patholog|rejection sensitivity|guaranteed|will always cause|certainly means you are)\b/i;

export function sanitizeTheoryCopy(text: string): string {
  const trimmed = text.replace(/\s+/g, " ").trim();
  if (!trimmed) return "This may be a working hypothesis from your recorded history.";
  if (FORBIDDEN_THEORY_OUTPUT.test(trimmed)) {
    return "This may be a repeating thread in your thinking history — worth checking against new moments.";
  }
  return trimmed;
}
