export type BlindSpotExperimentIngredient =
  | "criticism_rejection"
  | "prediction_failure"
  | "avoidance_delay"
  | "conflict_spiral"
  | "cross_life_area";

export type BlindSpotExperimentFeedbackRating = "will_try" | "not_useful" | "already_tried";

export interface BlindSpotExperiment {
  ingredient: BlindSpotExperimentIngredient;
  smallThing: string;
  tryNextTime: string;
  checkWhether: string;
}

export interface BlindSpotExperimentFeedbackRecord {
  id: string;
  reviewId: string;
  experimentIngredient: BlindSpotExperimentIngredient;
  rating: BlindSpotExperimentFeedbackRating;
  at: string;
}
