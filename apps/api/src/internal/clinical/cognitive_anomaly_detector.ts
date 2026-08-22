import "server-only";

import type { CognitiveBiomarkers } from "./cognitive_biomarkers";

/**
 * INTERNAL CLINICAL QUARANTINE — not for public API surfaces.
 * @module src/internal/clinical/cognitive_anomaly_detector
 */

export interface CognitiveAnomalyDetectorOptions {
  driftVarianceThreshold?: number;
  lexicalVarianceThreshold?: number;
}

export class CognitiveAnomalyDetector {
  readonly driftVarianceThreshold: number;
  readonly lexicalVarianceThreshold: number;

  constructor(options: CognitiveAnomalyDetectorOptions = {}) {
    this.driftVarianceThreshold = options.driftVarianceThreshold ?? 0.15;
    this.lexicalVarianceThreshold = options.lexicalVarianceThreshold ?? 0.1;
  }

  determineOverloadState(input: {
    current: CognitiveBiomarkers;
    baseline: CognitiveBiomarkers;
  }): boolean {
    const driftVariance = input.current.cohesionDrift - input.baseline.cohesionDrift;
    const lexicalVariance =
      input.baseline.lexicalDiversity - input.current.lexicalDiversity;

    return (
      driftVariance >= this.driftVarianceThreshold ||
      lexicalVariance >= this.lexicalVarianceThreshold
    );
  }
}
