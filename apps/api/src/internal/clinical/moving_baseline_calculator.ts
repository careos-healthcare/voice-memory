import "server-only";

import type { CognitiveBiomarkers } from "./cognitive_biomarkers";

/**
 * INTERNAL CLINICAL QUARANTINE — not for public API surfaces.
 * @module src/internal/clinical/moving_baseline_calculator
 */

export class MovingBaselineCalculator {
  readonly alpha: number;

  constructor(alpha = 0.3) {
    if (alpha <= 0 || alpha > 1) {
      throw new Error("Alpha smoothing factor must fall within (0, 1].");
    }
    this.alpha = alpha;
  }

  calculateMacroBaseline(history: readonly CognitiveBiomarkers[]): CognitiveBiomarkers | null {
    if (history.length === 0) return null;

    let cumulativeBaseline = history[0];
    for (let index = 1; index < history.length; index += 1) {
      cumulativeBaseline = this.updateBaseline(cumulativeBaseline, history[index]);
    }
    return cumulativeBaseline;
  }

  updateBaseline(
    previousBaseline: CognitiveBiomarkers,
    newObservation: CognitiveBiomarkers,
  ): CognitiveBiomarkers {
    return {
      lexicalDiversity:
        this.alpha * newObservation.lexicalDiversity +
        (1 - this.alpha) * previousBaseline.lexicalDiversity,
      cohesionDrift:
        this.alpha * newObservation.cohesionDrift +
        (1 - this.alpha) * previousBaseline.cohesionDrift,
      emotionalVolatility:
        this.alpha * newObservation.emotionalVolatility +
        (1 - this.alpha) * previousBaseline.emotionalVolatility,
    };
  }
}
