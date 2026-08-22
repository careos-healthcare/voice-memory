import { BLIND_SPOT_MIN_REFLECTIONS } from "@/lib/blind-spots/blind-spot-copy";

export const MINI_WOW_COPY = {
  panelTitle: "What ArchiveMe noticed",
  firstReflectionBody: "Saved. Patterns need repeated evidence.",
  disclaimer: "Early signal, not a conclusion",
  progressTowardReview: (count: number) =>
    `${count}/${BLIND_SPOT_MIN_REFLECTIONS} reflections toward a stronger pattern review`,
  scorecardIngredientLead: (label: string) =>
    `An early signal may be building: ${label.toLowerCase()} — not a conclusion.`,
  echoTitle: "Possible echo",
  formingTitle: "Possible pattern forming",
  formingConfidence: "Low confidence",
  previewTitle: "Early pattern preview",
  previewConfidence: "Building confidence",
  unlockedTitle: "Pattern review unlocked",
  unlockedBody:
    "You have enough reflections for a full blind spot review — still cautious, still tied to your words.",
  unlockedAction: "Open blind spot review",
} as const;
