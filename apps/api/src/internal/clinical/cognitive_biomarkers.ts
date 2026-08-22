import "server-only";

/**
 * INTERNAL CLINICAL QUARANTINE — not for public API surfaces.
 * @module src/internal/clinical/cognitive_biomarkers
 */

export interface CognitiveBiomarkers {
  lexicalDiversity: number;
  cohesionDrift: number;
  emotionalVolatility: number;
}

export function cognitiveBiomarkersFromJson(json: unknown): CognitiveBiomarkers | null {
  if (typeof json !== "object" || json === null) return null;
  const map = json as Record<string, unknown>;
  const lexicalDiversity = parseScore(map.lexicalDiversity);
  const cohesionDrift = parseScore(map.cohesionDrift);
  const emotionalVolatility = parseScore(map.emotionalVolatility);
  if (
    lexicalDiversity == null ||
    cohesionDrift == null ||
    emotionalVolatility == null
  ) {
    return null;
  }
  return { lexicalDiversity, cohesionDrift, emotionalVolatility };
}

export function cognitiveBiomarkersToJson(
  biomarkers: CognitiveBiomarkers,
): Record<string, number> {
  return {
    lexicalDiversity: biomarkers.lexicalDiversity,
    cohesionDrift: biomarkers.cohesionDrift,
    emotionalVolatility: biomarkers.emotionalVolatility,
  };
}

function parseScore(raw: unknown): number | null {
  if (typeof raw !== "number" || !Number.isFinite(raw)) return null;
  return raw;
}
