import type { ArchiveValueStage } from "@/types/archive-value";

/** Reflection-count milestones — evidence building, not passive logging. */
export const EVIDENCE_BUILDING_REFLECTION_LABELS: Record<
  1 | 2 | 3 | 4 | 5,
  { ladderLabel: string; statusLine: string; valueCopy: string }
> = {
  1: {
    ladderLabel: "One data point",
    statusLine: "One data point saved",
    valueCopy: "One data point saved.",
  },
  2: {
    ladderLabel: "Possible repeat",
    statusLine: "Possible repeat",
    valueCopy: "ArchiveMe can now check for possible repeats.",
  },
  3: {
    ladderLabel: "Evidence growing",
    statusLine: "Evidence growing",
    valueCopy: "Evidence may be accumulating across moments.",
  },
  4: {
    ladderLabel: "Theory under review",
    statusLine: "Theory under review",
    valueCopy: "A theory is under review.",
  },
  5: {
    ladderLabel: "First working theory unlocked",
    statusLine: "First working theory unlocked",
    valueCopy: "Your archive may be ready for a first working theory.",
  },
};

export function stageForReflectionCount(count: number): ArchiveValueStage {
  if (count <= 0) return "one_data_point";
  if (count === 1) return "one_data_point";
  if (count === 2) return "possible_repeat";
  if (count === 3) return "pattern_forming";
  if (count === 4) return "theory_under_review";
  return "pattern_review_unlocked";
}

export function evidenceBuildingLabelForCount(count: number): string {
  const clamped = Math.min(5, Math.max(1, count)) as 1 | 2 | 3 | 4 | 5;
  return EVIDENCE_BUILDING_REFLECTION_LABELS[clamped].statusLine;
}

export function evidenceBuildingValueCopyForCount(count: number): string {
  if (count <= 0) return "Your archive is waiting for a first moment.";
  const clamped = Math.min(5, Math.max(1, count)) as 1 | 2 | 3 | 4 | 5;
  return EVIDENCE_BUILDING_REFLECTION_LABELS[clamped].valueCopy;
}

export function ladderLabelForStage(stage: ArchiveValueStage): string {
  switch (stage) {
    case "one_data_point":
      return EVIDENCE_BUILDING_REFLECTION_LABELS[1].ladderLabel;
    case "possible_repeat":
      return EVIDENCE_BUILDING_REFLECTION_LABELS[2].ladderLabel;
    case "pattern_forming":
      return EVIDENCE_BUILDING_REFLECTION_LABELS[3].ladderLabel;
    case "theory_under_review":
      return EVIDENCE_BUILDING_REFLECTION_LABELS[4].ladderLabel;
    case "pattern_review_unlocked":
      return EVIDENCE_BUILDING_REFLECTION_LABELS[5].ladderLabel;
    default:
      return EVIDENCE_BUILDING_REFLECTION_LABELS[1].ladderLabel;
  }
}

export function nextEvidenceMilestoneCopy(count: number): string {
  if (count >= 5) return "Open your first working theory.";
  if (count === 4) return "1 more moment until your first working theory.";
  if (count === 3) return "1 more moment until your first working theory.";
  if (count === 2) return "1 more moment until ArchiveMe can compare this properly.";
  if (count === 1) return "1 more moment until ArchiveMe can compare this properly.";
  return "Record your first moment.";
}
