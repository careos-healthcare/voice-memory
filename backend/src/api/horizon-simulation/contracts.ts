export const HORIZON_YEARS = [1, 3, 5] as const;
export const HORIZON_PRIVACY_HEADERS = {
  "Cache-Control": "no-store, max-age=0",
  "X-AI-Data-Retention": "none",
  "X-OpenAI-Store": "false",
} as const;

const TOKEN = /^[a-z0-9][a-z0-9_-]{0,63}$/;
const FORBIDDEN = [
  "userid",
  "entryid",
  "name",
  "label",
  "text",
  "content",
  "quote",
  "transcript",
  "evidence",
  "path",
];

export interface HorizonSimulationRequest {
  divergence: { typeToken: string; confidence: number; degree: number };
  clusters: Array<{
    token: string;
    category: string;
    size: number;
    velocity: number;
    confidence: number;
  }>;
  parameters: {
    resourceCommitment: number;
    changeTolerance: number;
    timeCommitment: number;
    uncertaintyTolerance: number;
  };
}

export interface HorizonSimulationResult {
  projections: Array<{
    id: string;
    year: 1 | 3 | 5;
    label: string;
    nodeType: string;
    probability: number;
    vectors: {
      financial: number;
      emotional: number;
      career: number;
      cognitiveLoad: number;
      alignment: number;
      reward: number;
    };
    rippleEffects: string[];
  }>;
}

export function parseHorizonSimulationRequest(
  value: unknown,
): HorizonSimulationRequest {
  rejectPrivateFields(value);
  const root = strictRecord(
    value,
    ["divergence", "clusters", "parameters"],
    "request",
  );
  const divergence = strictRecord(
    root.divergence,
    ["typeToken", "confidence", "degree"],
    "divergence",
  );
  const clusters = boundedArray(root.clusters, 0, 24, "clusters").map(
    (value, index) => {
      const row = strictRecord(
        value,
        ["token", "category", "size", "velocity", "confidence"],
        `clusters[${index}]`,
      );
      return {
        token: token(row.token, `clusters[${index}].token`),
        category: token(row.category, `clusters[${index}].category`),
        size: integer(row.size, 0, 500, `clusters[${index}].size`),
        velocity: unit(row.velocity, `clusters[${index}].velocity`),
        confidence: unit(row.confidence, `clusters[${index}].confidence`),
      };
    },
  );
  const parameters = strictRecord(
    root.parameters,
    [
      "resourceCommitment",
      "changeTolerance",
      "timeCommitment",
      "uncertaintyTolerance",
    ],
    "parameters",
  );
  return {
    divergence: {
      typeToken: token(divergence.typeToken, "divergence.typeToken"),
      confidence: unit(divergence.confidence, "divergence.confidence"),
      degree: integer(divergence.degree, 0, 512, "divergence.degree"),
    },
    clusters,
    parameters: {
      resourceCommitment: unit(
        parameters.resourceCommitment,
        "parameters.resourceCommitment",
      ),
      changeTolerance: unit(
        parameters.changeTolerance,
        "parameters.changeTolerance",
      ),
      timeCommitment: unit(
        parameters.timeCommitment,
        "parameters.timeCommitment",
      ),
      uncertaintyTolerance: unit(
        parameters.uncertaintyTolerance,
        "parameters.uncertaintyTolerance",
      ),
    },
  };
}

export function parseHorizonSimulationResult(
  value: unknown,
): HorizonSimulationResult {
  const root = strictRecord(value, ["projections"], "result");
  const projections = boundedArray(root.projections, 3, 3, "projections").map(
    (value, index) => {
      const row = strictRecord(
        value,
        [
          "id",
          "year",
          "label",
          "nodeType",
          "probability",
          "vectors",
          "rippleEffects",
        ],
        `projections[${index}]`,
      );
      const vectors = strictRecord(
        row.vectors,
        [
          "financial",
          "emotional",
          "career",
          "cognitiveLoad",
          "alignment",
          "reward",
        ],
        `projections[${index}].vectors`,
      );
      const year = integer(row.year, 1, 5, `projections[${index}].year`);
      if (!HORIZON_YEARS.includes(year as 1 | 3 | 5)) {
        throw new Error("Projection years must be 1, 3, and 5.");
      }
      return {
        id: token(row.id, `projections[${index}].id`),
        year: year as 1 | 3 | 5,
        label: boundedString(row.label, 1, 240, `projections[${index}].label`),
        nodeType: token(row.nodeType, `projections[${index}].nodeType`),
        probability: unit(
          row.probability,
          `projections[${index}].probability`,
        ),
        vectors: {
          financial: unit(vectors.financial, "vectors.financial"),
          emotional: unit(vectors.emotional, "vectors.emotional"),
          career: unit(vectors.career, "vectors.career"),
          cognitiveLoad: unit(vectors.cognitiveLoad, "vectors.cognitiveLoad"),
          alignment: unit(vectors.alignment, "vectors.alignment"),
          reward: unit(vectors.reward, "vectors.reward"),
        },
        rippleEffects: boundedArray(
          row.rippleEffects,
          0,
          8,
          `projections[${index}].rippleEffects`,
        ).map((item) => boundedString(item, 1, 160, "ripple effect")),
      };
    },
  );
  const years = projections.map((item) => item.year).sort();
  if (years.join(",") !== HORIZON_YEARS.join(",")) {
    throw new Error("Projection years must be unique and complete.");
  }
  return { projections };
}

function rejectPrivateFields(value: unknown): void {
  if (Array.isArray(value)) {
    value.forEach(rejectPrivateFields);
    return;
  }
  if (!value || typeof value !== "object") return;
  for (const [key, child] of Object.entries(value)) {
    const normalized = key.toLowerCase().replaceAll(/[^a-z0-9]/g, "");
    if (FORBIDDEN.some((part) => normalized.includes(part))) {
      throw new Error(`Private field "${key}" is not permitted.`);
    }
    rejectPrivateFields(child);
  }
}

function strictRecord(
  value: unknown,
  keys: readonly string[],
  label: string,
): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`${label} must be an object.`);
  }
  const record = value as Record<string, unknown>;
  if (
    Object.keys(record).length !== keys.length ||
    Object.keys(record).some((key) => !keys.includes(key))
  ) {
    throw new Error(`${label} fields are invalid.`);
  }
  return record;
}

function boundedArray(
  value: unknown,
  minimum: number,
  maximum: number,
  label: string,
): unknown[] {
  if (!Array.isArray(value) || value.length < minimum || value.length > maximum) {
    throw new Error(`${label} has an invalid length.`);
  }
  return value;
}

function boundedString(
  value: unknown,
  minimum: number,
  maximum: number,
  label: string,
): string {
  if (
    typeof value !== "string" ||
    value.trim().length < minimum ||
    value.trim().length > maximum
  ) {
    throw new Error(`${label} is invalid.`);
  }
  return value.trim();
}

function token(value: unknown, label: string): string {
  const result = boundedString(value, 1, 64, label);
  if (!TOKEN.test(result)) throw new Error(`${label} must be a token.`);
  return result;
}

function unit(value: unknown, label: string): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0 || value > 1) {
    throw new Error(`${label} must be between zero and one.`);
  }
  return value;
}

function integer(
  value: unknown,
  minimum: number,
  maximum: number,
  label: string,
): number {
  if (
    typeof value !== "number" ||
    !Number.isInteger(value) ||
    value < minimum ||
    value > maximum
  ) {
    throw new Error(`${label} must be an integer.`);
  }
  return value;
}
