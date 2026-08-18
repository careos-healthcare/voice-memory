import { ARCHIVE_EMOTIONAL } from "@/lib/archive/archive-emotional-copy";
import { ARCHIVE_VALUE_POSITIONING } from "@/lib/product/archive-value-copy";

export const ARCHIVE_MOVEMENT_EYEBROW = "Archive update";

export const ARCHIVE_MOVEMENT_COPY = {
  confidenceIncreased: ARCHIVE_EMOTIONAL.confidenceIncreased,
  confidenceDecreased: ARCHIVE_EMOTIONAL.theoryWeakened,
  confidenceReasonSupport: "New experiences supported this view.",
  confidenceReasonWeaken: "Recent reflections challenged this belief.",
  evidenceAdded: ARCHIVE_EMOTIONAL.evidenceAdded,
  evidenceHarderToFool: ARCHIVE_VALUE_POSITIONING.archiveHarderToFool,
  statusChanged: "Status changed",
  contradictionHeadline: "Possible contradiction detected",
  contradictionReason:
    "Your archive now contains evidence pointing in two directions.",
  costHeadline: "Cost evidence detected",
  costReason: "Your archive may be linking patterns to what followed them.",
  lifeAreaHeadline: "New life area linked",
  lifeAreaReason: "This pattern may now span more than one area of your life.",
  underReviewHeadline: "No major change yet",
  underReviewReason: "Your archive is still evaluating this theory.",
} as const;
