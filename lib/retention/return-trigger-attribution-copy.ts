import type { ReturnExpectationMet, ReturnTriggerReasonId } from "@/types/return-trigger-attribution";

export const RETURN_TRIGGER_REASON_QUESTION = "What were you hoping to check?";

export const RETURN_EXPECTATION_QUESTION = "Did you find what you were looking for?";

export const RETURN_TRIGGER_REASON_LABELS: Record<ReturnTriggerReasonId, string> = {
  archive_view_changed: "Whether my archive changed its view",
  theory_stronger: "Whether a theory got stronger",
  theory_disappeared: "Whether a theory disappeared",
  new_blind_spot: "Whether there was a new blind spot",
  confidence_changed: "Whether confidence changed",
  wanted_to_record: "I wanted to record something",
  just_curious: "Just curious",
  other: "Other",
};

export const RETURN_EXPECTATION_LABELS: Record<ReturnExpectationMet, string> = {
  yes: "Yes",
  partly: "Partly",
  no: "No",
};

export const RETURN_TRIGGER_ATTRIBUTION_DISMISS = "Not today";
