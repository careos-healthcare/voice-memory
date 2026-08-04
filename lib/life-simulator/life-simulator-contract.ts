import type {
  LifeSimulatorDirection,
  LifeSimulatorHorizonDays,
  LifeSimulatorMilestone,
  LifeSimulatorRequest,
  LifeSimulatorResult,
  LifeSimulatorTrajectory,
} from "@/types/life-simulator";

export const LIFE_SIMULATOR_HORIZONS = [30, 90, 365] as const;
export const MAX_LIFE_SIMULATOR_NODES = 64;
export const MAX_LIFE_SIMULATOR_EDGES = 128;
export const MAX_LIFE_SIMULATOR_CITATIONS = 64;

const DIRECTIONS = ["negative", "neutral", "positive"] as const;
const TOKEN = /^[a-z0-9][a-z0-9._:-]{0,63}$/;
const OPAQUE_ID = /^[A-Za-z0-9_-]{1,128}$/;
const FORBIDDEN_FIELD_PARTS = [
  "userid",
  "entryid",
  "quote",
  "transcript",
  "label",
  "evidence",
  "text",
  "content",
  "audio",
  "media",
  "path",
] as const;

const milestoneSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    horizonDays: { type: "integer", enum: LIFE_SIMULATOR_HORIZONS },
    narrativeSummary: { type: "string", minLength: 1, maxLength: 480 },
    projectedConfidence: { type: "number", minimum: 0, maximum: 1 },
    stressImpactScore: { type: "number", minimum: -1, maximum: 1 },
    healthCorrelation: {
      anyOf: [
        { type: "number", minimum: -1, maximum: 1 },
        { type: "null" },
      ],
    },
    affectedIds: {
      type: "array",
      maxItems: 32,
      uniqueItems: true,
      items: { type: "string", minLength: 1, maxLength: 128 },
    },
    citationHandles: {
      type: "array",
      maxItems: MAX_LIFE_SIMULATOR_CITATIONS,
      uniqueItems: true,
      items: { type: "string", minLength: 1, maxLength: 128 },
    },
  },
  required: [
    "horizonDays",
    "narrativeSummary",
    "projectedConfidence",
    "stressImpactScore",
    "healthCorrelation",
    "affectedIds",
    "citationHandles",
  ],
} as const;

const trajectorySchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    summary: { type: "string", minLength: 1, maxLength: 640 },
    milestones: {
      type: "array",
      minItems: LIFE_SIMULATOR_HORIZONS.length,
      maxItems: LIFE_SIMULATOR_HORIZONS.length,
      items: milestoneSchema,
    },
  },
  required: ["summary", "milestones"],
} as const;

export const LifeSimulatorResultSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    continueTrajectory: trajectorySchema,
    stopOrPivotTrajectory: trajectorySchema,
  },
  required: ["continueTrajectory", "stopOrPivotTrajectory"],
} as const;

export function parseLifeSimulatorRequest(value: unknown): LifeSimulatorRequest {
  rejectForbiddenFields(value);
  const object = strictRecord(
    value,
    [
      "target",
      "nodes",
      "edges",
      "aggregateTopology",
      "historicalDeltas",
      "externalCorrelationSummaries",
      "citations",
    ],
    "Life simulator request",
  );
  const target = strictRecord(
    object.target,
    ["categoryToken", "typeToken"],
    "target",
  );
  const nodes = boundedArray(
    object.nodes,
    1,
    MAX_LIFE_SIMULATOR_NODES,
    "nodes",
  ).map((value, index) => {
    const node = strictRecord(value, ["id", "typeToken", "weight"], `nodes[${index}]`);
    return {
      id: opaqueId(node.id, `nodes[${index}].id`),
      typeToken: token(node.typeToken, `nodes[${index}].typeToken`),
      weight: boundedNumber(node.weight, 0, 1, `nodes[${index}].weight`),
    };
  });
  ensureUnique(nodes.map((node) => node.id), "Node IDs");
  const nodeIds = new Set(nodes.map((node) => node.id));

  const edges = boundedArray(
    object.edges,
    0,
    MAX_LIFE_SIMULATOR_EDGES,
    "edges",
  ).map((value, index) => {
    const edge = strictRecord(
      value,
      ["id", "sourceNodeId", "targetNodeId", "typeToken", "weight"],
      `edges[${index}]`,
    );
    const sourceNodeId = opaqueId(edge.sourceNodeId, `edges[${index}].sourceNodeId`);
    const targetNodeId = opaqueId(edge.targetNodeId, `edges[${index}].targetNodeId`);
    if (!nodeIds.has(sourceNodeId) || !nodeIds.has(targetNodeId)) {
      throw new Error(`edges[${index}] references an unknown node ID.`);
    }
    return {
      id: opaqueId(edge.id, `edges[${index}].id`),
      sourceNodeId,
      targetNodeId,
      typeToken: token(edge.typeToken, `edges[${index}].typeToken`),
      weight: boundedNumber(edge.weight, 0, 1, `edges[${index}].weight`),
    };
  });
  ensureUnique(edges.map((edge) => edge.id), "Edge IDs");
  const allIds = new Set([...nodeIds, ...edges.map((edge) => edge.id)]);
  if (allIds.size !== nodes.length + edges.length) {
    throw new Error("Node and edge IDs must not overlap.");
  }

  const topology = strictRecord(
    object.aggregateTopology,
    ["nodeCount", "edgeCount", "density", "componentCount"],
    "aggregateTopology",
  );
  const nodeCount = boundedInteger(topology.nodeCount, 1, MAX_LIFE_SIMULATOR_NODES, "nodeCount");
  const edgeCount = boundedInteger(topology.edgeCount, 0, MAX_LIFE_SIMULATOR_EDGES, "edgeCount");
  if (nodeCount !== nodes.length || edgeCount !== edges.length) {
    throw new Error("Aggregate topology counts must match anonymous nodes and edges.");
  }

  const historicalDeltas = boundedArray(
    object.historicalDeltas,
    0,
    128,
    "historicalDeltas",
  ).map((value, index) => {
    const delta = strictRecord(
      value,
      ["windowDays", "affectedId", "metricToken", "delta"],
      `historicalDeltas[${index}]`,
    );
    const affectedId = opaqueId(delta.affectedId, `historicalDeltas[${index}].affectedId`);
    if (!allIds.has(affectedId)) {
      throw new Error(`historicalDeltas[${index}] references an unknown anonymous ID.`);
    }
    return {
      windowDays: boundedInteger(delta.windowDays, 1, 3_650, `historicalDeltas[${index}].windowDays`),
      affectedId,
      metricToken: token(delta.metricToken, `historicalDeltas[${index}].metricToken`),
      delta: boundedNumber(delta.delta, -1, 1, `historicalDeltas[${index}].delta`),
    };
  });

  const externalCorrelationSummaries = boundedArray(
    object.externalCorrelationSummaries,
    0,
    64,
    "externalCorrelationSummaries",
  ).map((value, index) => {
    const correlation = strictRecord(
      value,
      ["signalToken", "direction", "strength", "sampleSize", "lagDays"],
      `externalCorrelationSummaries[${index}]`,
    );
    return {
      signalToken: token(correlation.signalToken, `externalCorrelationSummaries[${index}].signalToken`),
      direction: direction(correlation.direction, `externalCorrelationSummaries[${index}].direction`),
      strength: boundedNumber(correlation.strength, 0, 1, `externalCorrelationSummaries[${index}].strength`),
      sampleSize: boundedInteger(correlation.sampleSize, 1, 1_000_000, `externalCorrelationSummaries[${index}].sampleSize`),
      lagDays: boundedInteger(correlation.lagDays, -3_650, 3_650, `externalCorrelationSummaries[${index}].lagDays`),
    };
  });

  const citations = boundedArray(
    object.citations,
    0,
    MAX_LIFE_SIMULATOR_CITATIONS,
    "citations",
  ).map((value, index) => {
    const citation = strictRecord(
      value,
      ["handle", "signalToken", "direction", "strength", "recencyDays"],
      `citations[${index}]`,
    );
    return {
      handle: opaqueId(citation.handle, `citations[${index}].handle`),
      signalToken: token(citation.signalToken, `citations[${index}].signalToken`),
      direction: direction(citation.direction, `citations[${index}].direction`),
      strength: boundedNumber(citation.strength, 0, 1, `citations[${index}].strength`),
      recencyDays: boundedInteger(citation.recencyDays, 0, 3_650, `citations[${index}].recencyDays`),
    };
  });
  ensureUnique(citations.map((citation) => citation.handle), "Citation handles");

  return {
    target: {
      categoryToken: token(target.categoryToken, "target.categoryToken"),
      typeToken: token(target.typeToken, "target.typeToken"),
    },
    nodes,
    edges,
    aggregateTopology: {
      nodeCount,
      edgeCount,
      density: boundedNumber(topology.density, 0, 1, "density"),
      componentCount: boundedInteger(topology.componentCount, 1, nodeCount, "componentCount"),
    },
    historicalDeltas,
    externalCorrelationSummaries,
    citations,
  };
}

export function parseLifeSimulatorResult(
  value: unknown,
  request: LifeSimulatorRequest,
): LifeSimulatorResult {
  const object = strictRecord(
    value,
    ["continueTrajectory", "stopOrPivotTrajectory"],
    "Life simulator result",
  );
  const allowedIds = new Set([
    ...request.nodes.map((node) => node.id),
    ...request.edges.map((edge) => edge.id),
  ]);
  const allowedHandles = new Set(request.citations.map((citation) => citation.handle));
  return {
    continueTrajectory: parseTrajectory(
      object.continueTrajectory,
      "continueTrajectory",
      allowedIds,
      allowedHandles,
    ),
    stopOrPivotTrajectory: parseTrajectory(
      object.stopOrPivotTrajectory,
      "stopOrPivotTrajectory",
      allowedIds,
      allowedHandles,
    ),
  };
}

function parseTrajectory(
  value: unknown,
  label: string,
  allowedIds: ReadonlySet<string>,
  allowedHandles: ReadonlySet<string>,
): LifeSimulatorTrajectory {
  const object = strictRecord(value, ["summary", "milestones"], label);
  const milestones = boundedArray(
    object.milestones,
    LIFE_SIMULATOR_HORIZONS.length,
    LIFE_SIMULATOR_HORIZONS.length,
    `${label}.milestones`,
  ).map((milestone, index) =>
    parseMilestone(
      milestone,
      `${label}.milestones[${index}]`,
      allowedIds,
      allowedHandles,
    ),
  );
  if (
    milestones.some(
      (milestone, index) => milestone.horizonDays !== LIFE_SIMULATOR_HORIZONS[index],
    )
  ) {
    throw new Error(`${label} milestone horizons must be exactly 30, 90, and 365 in order.`);
  }
  return {
    summary: boundedString(object.summary, 640, `${label}.summary`),
    milestones,
  };
}

function parseMilestone(
  value: unknown,
  label: string,
  allowedIds: ReadonlySet<string>,
  allowedHandles: ReadonlySet<string>,
): LifeSimulatorMilestone {
  const object = strictRecord(
    value,
    [
      "horizonDays",
      "narrativeSummary",
      "projectedConfidence",
      "stressImpactScore",
      "healthCorrelation",
      "affectedIds",
      "citationHandles",
    ],
    label,
  );
  const horizonDays = boundedInteger(object.horizonDays, 30, 365, `${label}.horizonDays`);
  if (!LIFE_SIMULATOR_HORIZONS.includes(horizonDays as LifeSimulatorHorizonDays)) {
    throw new Error(`${label}.horizonDays is invalid.`);
  }
  const affectedIds = stringArray(object.affectedIds, 32, `${label}.affectedIds`, opaqueId);
  const citationHandles = stringArray(
    object.citationHandles,
    MAX_LIFE_SIMULATOR_CITATIONS,
    `${label}.citationHandles`,
    opaqueId,
  );
  if (affectedIds.some((id) => !allowedIds.has(id))) {
    throw new Error(`${label}.affectedIds contains an ID not present in the request.`);
  }
  if (citationHandles.some((handle) => !allowedHandles.has(handle))) {
    throw new Error(`${label}.citationHandles contains a handle not present in the request.`);
  }
  return {
    horizonDays: horizonDays as LifeSimulatorHorizonDays,
    narrativeSummary: boundedString(
      object.narrativeSummary,
      480,
      `${label}.narrativeSummary`,
    ),
    projectedConfidence: boundedNumber(
      object.projectedConfidence,
      0,
      1,
      `${label}.projectedConfidence`,
    ),
    stressImpactScore: boundedNumber(
      object.stressImpactScore,
      -1,
      1,
      `${label}.stressImpactScore`,
    ),
    healthCorrelation:
      object.healthCorrelation === null
        ? null
        : boundedNumber(
            object.healthCorrelation,
            -1,
            1,
            `${label}.healthCorrelation`,
          ),
    affectedIds,
    citationHandles,
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
    if (FORBIDDEN_FIELD_PARTS.some((part) => normalized.includes(part))) {
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

function boundedArray(value: unknown, min: number, max: number, label: string): unknown[] {
  if (!Array.isArray(value) || value.length < min || value.length > max) {
    throw new Error(`${label} must contain between ${min} and ${max} items.`);
  }
  return value;
}

function stringArray(
  value: unknown,
  max: number,
  label: string,
  parser: (value: unknown, label: string) => string,
): string[] {
  const result = boundedArray(value, 0, max, label).map((item, index) =>
    parser(item, `${label}[${index}]`),
  );
  ensureUnique(result, label);
  return result;
}

function token(value: unknown, label: string): string {
  if (typeof value !== "string" || !TOKEN.test(value)) {
    throw new Error(`${label} must be a lowercase structural token.`);
  }
  return value;
}

function opaqueId(value: unknown, label: string): string {
  if (typeof value !== "string" || !OPAQUE_ID.test(value)) {
    throw new Error(`${label} must be an opaque identifier.`);
  }
  return value;
}

function direction(value: unknown, label: string): LifeSimulatorDirection {
  if (!DIRECTIONS.includes(value as LifeSimulatorDirection)) {
    throw new Error(`${label} is invalid.`);
  }
  return value as LifeSimulatorDirection;
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

function boundedNumber(value: unknown, min: number, max: number, label: string): number {
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

function boundedInteger(value: unknown, min: number, max: number, label: string): number {
  const result = boundedNumber(value, min, max, label);
  if (!Number.isInteger(result)) throw new Error(`${label} must be an integer.`);
  return result;
}

function ensureUnique(values: readonly string[], label: string): void {
  if (new Set(values).size !== values.length) {
    throw new Error(`${label} must be unique.`);
  }
}
