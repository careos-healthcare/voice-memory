import type { BlindSpotExperiment } from "@/types/blind-spot-experiment";

export function formatBlindSpotExperimentText(experiment: BlindSpotExperiment): string {
  return [experiment.smallThing, experiment.tryNextTime, experiment.checkWhether].join(" ");
}
