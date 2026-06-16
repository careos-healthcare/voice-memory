import { ladderLabelForStage } from "@/lib/theories/personal-theory-status";
import {
  evidenceBuildingValueCopyForCount,
} from "@/lib/theories/personal-theory-status";
import type { ArchiveValueStage } from "@/types/archive-value";

export const ARCHIVE_VALUE_POSITIONING = {
  singleMomentToday:
    "Today's recording is one data point. ArchiveMe gets stronger as your archive grows.",
  eachReflection:
    "Each reflection gives ArchiveMe more evidence about what keeps repeating.",
  archiveHarderToFool: "Your archive is becoming harder to fool.",
} as const;

export const ARCHIVE_VALUE_STAGE_COPY: Record<
  ArchiveValueStage,
  { valueCopy: string; ladderLabel: string }
> = {
  one_data_point: {
    valueCopy: evidenceBuildingValueCopyForCount(1),
    ladderLabel: ladderLabelForStage("one_data_point"),
  },
  possible_repeat: {
    valueCopy: evidenceBuildingValueCopyForCount(2),
    ladderLabel: ladderLabelForStage("possible_repeat"),
  },
  pattern_forming: {
    valueCopy: evidenceBuildingValueCopyForCount(3),
    ladderLabel: ladderLabelForStage("pattern_forming"),
  },
  theory_under_review: {
    valueCopy: evidenceBuildingValueCopyForCount(4),
    ladderLabel: ladderLabelForStage("theory_under_review"),
  },
  pattern_review_unlocked: {
    valueCopy: evidenceBuildingValueCopyForCount(5),
    ladderLabel: ladderLabelForStage("pattern_review_unlocked"),
  },
};

export const REFLECTION_VALUE_LADDER = [
  { reflections: 1, stage: "one_data_point" as const },
  { reflections: 2, stage: "possible_repeat" as const },
  { reflections: 3, stage: "pattern_forming" as const },
  { reflections: 4, stage: "theory_under_review" as const },
  { reflections: 5, stage: "pattern_review_unlocked" as const },
] as const;

export const PATTERN_REVIEW_TARGET = 5;
