export const MAX_CLUSTER_SYNTHESIS_NODES = 64;

export interface ClusterSynthesisNode {
  anonymousId: string;
  type: string;
  label: string;
  degree: number;
  activityWeight: number;
}

export interface ClusterSynthesisRequest {
  clusterId: string;
  category: string;
  candidateTitle: string;
  nodes: ClusterSynthesisNode[];
  edgeMetrics: {
    edgeCount: number;
    density: number;
    averageWeight: number;
  };
  vectorMetrics: {
    cohesion: number;
    separation: number;
    centroidMagnitude: number;
  };
  velocityMetrics: {
    averageVelocity: number;
    acceleration: number;
    stability: number;
  };
}

export interface ClusterSynthesisResult {
  title: string;
  briefSummary: string;
  category: string;
  confidenceScore: number;
}

export const ClusterSynthesisResultSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    title: { type: "string", minLength: 1, maxLength: 120 },
    briefSummary: { type: "string", minLength: 1, maxLength: 320 },
    category: { type: "string", minLength: 1, maxLength: 64 },
    confidenceScore: { type: "number", minimum: 0, maximum: 1 },
  },
  required: ["title", "briefSummary", "category", "confidenceScore"],
} as const;

const REQUEST_FIELDS = [
  "clusterId",
  "category",
  "candidateTitle",
  "nodes",
  "edgeMetrics",
  "vectorMetrics",
  "velocityMetrics",
] as const;

const FORBIDDEN_FIELD_NAMES = new Set([
  "content",
  "raw",
  "rawcontent",
  "rawtext",
  "textcontent",
  "userid",
]);

const FORBIDDEN_FIELD_PREFIXES = [
  "audio",
  "evidence",
  "rawcontent",
  "transcript",
] as const;

export function parseClusterSynthesisRequest(
  value: unknown,
): ClusterSynthesisRequest {
  rejectForbiddenFields(value);
  const object = strictRecord(value, REQUEST_FIELDS, "Cluster synthesis request");
  if (!Array.isArray(object.nodes) || object.nodes.length < 1 || object.nodes.length > MAX_CLUSTER_SYNTHESIS_NODES) {
    throw new Error(`nodes must contain between 1 and ${MAX_CLUSTER_SYNTHESIS_NODES} items.`);
  }

  const nodes = object.nodes.map((value): ClusterSynthesisNode => {
    const node = strictRecord(
      value,
      ["anonymousId", "type", "label", "degree", "activityWeight"],
      "Cluster node",
    );
    return {
      anonymousId: anonymousId(node.anonymousId, "anonymousId"),
      type: boundedStructuralLabel(node.type, 48, "type"),
      label: boundedStructuralLabel(node.label, 120, "label"),
      degree: boundedInteger(node.degree, 0, 10_000, "degree"),
      activityWeight: boundedNumber(
        node.activityWeight,
        0,
        1,
        "activityWeight",
      ),
    };
  });
  if (new Set(nodes.map((node) => node.anonymousId)).size !== nodes.length) {
    throw new Error("anonymousId values must be unique.");
  }

  const edge = strictRecord(
    object.edgeMetrics,
    ["edgeCount", "density", "averageWeight"],
    "edgeMetrics",
  );
  const vector = strictRecord(
    object.vectorMetrics,
    ["cohesion", "separation", "centroidMagnitude"],
    "vectorMetrics",
  );
  const velocity = strictRecord(
    object.velocityMetrics,
    ["averageVelocity", "acceleration", "stability"],
    "velocityMetrics",
  );

  return {
    clusterId: anonymousId(object.clusterId, "clusterId"),
    category: boundedStructuralLabel(object.category, 64, "category"),
    candidateTitle: boundedStructuralLabel(
      object.candidateTitle,
      120,
      "candidateTitle",
    ),
    nodes,
    edgeMetrics: {
      edgeCount: boundedInteger(edge.edgeCount, 0, 100_000, "edgeCount"),
      density: boundedNumber(edge.density, 0, 1, "density"),
      averageWeight: boundedNumber(
        edge.averageWeight,
        0,
        1,
        "averageWeight",
      ),
    },
    vectorMetrics: {
      cohesion: boundedNumber(vector.cohesion, 0, 1, "cohesion"),
      separation: boundedNumber(vector.separation, 0, 1, "separation"),
      centroidMagnitude: boundedNumber(
        vector.centroidMagnitude,
        0,
        1_000_000,
        "centroidMagnitude",
      ),
    },
    velocityMetrics: {
      averageVelocity: boundedNumber(
        velocity.averageVelocity,
        -1_000_000,
        1_000_000,
        "averageVelocity",
      ),
      acceleration: boundedNumber(
        velocity.acceleration,
        -1_000_000,
        1_000_000,
        "acceleration",
      ),
      stability: boundedNumber(velocity.stability, 0, 1, "stability"),
    },
  };
}

export function parseClusterSynthesisResult(
  value: unknown,
): ClusterSynthesisResult {
  const object = strictRecord(
    value,
    ["title", "briefSummary", "category", "confidenceScore"],
    "Cluster synthesis result",
  );
  return {
    title: boundedString(object.title, 120, "title"),
    briefSummary: boundedString(
      object.briefSummary,
      320,
      "briefSummary",
    ),
    category: boundedString(object.category, 64, "category"),
    confidenceScore: boundedNumber(
      object.confidenceScore,
      0,
      1,
      "confidenceScore",
    ),
  };
}

function rejectForbiddenFields(value: unknown): void {
  if (Array.isArray(value)) {
    value.forEach(rejectForbiddenFields);
    return;
  }
  if (!value || typeof value !== "object") return;
  for (const [key, child] of Object.entries(value as Record<string, unknown>)) {
    const normalized = key.replace(/[^a-z0-9]/gi, "").toLowerCase();
    if (
      FORBIDDEN_FIELD_NAMES.has(normalized) ||
      FORBIDDEN_FIELD_PREFIXES.some((prefix) => normalized.includes(prefix))
    ) {
      throw new Error(`Forbidden personal-content field: ${key}.`);
    }
    rejectForbiddenFields(child);
  }
}

function strictRecord(
  value: unknown,
  allowedKeys: readonly string[],
  label: string,
): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`${label} must be an object.`);
  }
  const object = value as Record<string, unknown>;
  if (Object.keys(object).some((key) => !allowedKeys.includes(key))) {
    throw new Error(`${label} contains unknown fields.`);
  }
  if (allowedKeys.some((key) => !(key in object))) {
    throw new Error(`${label} is missing required fields.`);
  }
  return object;
}

function anonymousId(value: unknown, label: string): string {
  if (
    typeof value !== "string" ||
    value.length < 1 ||
    value.length > 128 ||
    !/^[A-Za-z0-9_-]+$/.test(value)
  ) {
    throw new Error(`${label} must be an anonymous identifier.`);
  }
  return value;
}

function boundedStructuralLabel(
  value: unknown,
  max: number,
  label: string,
): string {
  const result = boundedString(value, max, label);
  if (/[\r\n]/.test(result)) {
    throw new Error(`${label} must be a single structural label.`);
  }
  return result;
}

function boundedString(value: unknown, max: number, label: string): string {
  if (
    typeof value !== "string" ||
    value.trim().length === 0 ||
    value.length > max ||
    /[\u0000-\u001F\u007F]/.test(value)
  ) {
    throw new Error(`${label} is invalid.`);
  }
  return value.trim();
}

function boundedNumber(
  value: unknown,
  min: number,
  max: number,
  label: string,
): number {
  if (
    typeof value !== "number" ||
    !Number.isFinite(value) ||
    value < min ||
    value > max
  ) {
    throw new Error(`${label} must be between ${min} and ${max}.`);
  }
  return value;
}

function boundedInteger(
  value: unknown,
  min: number,
  max: number,
  label: string,
): number {
  const number = boundedNumber(value, min, max, label);
  if (!Number.isInteger(number)) throw new Error(`${label} must be an integer.`);
  return number;
}
