import { ARCHIVE_VOICE_FORBIDDEN_UNIFIED } from "@/lib/archive/archive-voice";

export const SESSION_MOVEMENT_HEADING = "What changed";

export const SESSION_MOVEMENT_FORBIDDEN = ARCHIVE_VOICE_FORBIDDEN_UNIFIED;

export const SESSION_MOVEMENT_COPY = {
  beliefChanged: "Your archive updated its view of a belief.",
  confidenceMoved: "Confidence moved",
  newEvidence: "Your archive added new evidence to an existing belief.",
  contradiction: "A contradiction appeared.",
  beliefWeakened: "A belief weakened as new evidence arrived.",
  beliefStrengthened: "A belief strengthened as new evidence arrived.",
  comparisonPoint:
    "No major change yet. This reflection still gives the archive another comparison point.",
  comparisonBrowse:
    "No major change since your last visit. The archive is still comparing new evidence against your history.",
} as const;
