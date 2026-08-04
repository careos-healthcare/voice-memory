import type {
  ActionPlanAggregateMetric,
  ActionPlanEdge,
  ActionPlanGeneratorRequest,
  ActionPlanGeneratorResult,
  ActionPlanHorizonDays,
  ActionPlanMicroHabit,
  ActionPlanNode,
  ActionPlanWeekday,
} from "@/types/action-plan-generator";

export const ACTION_PLAN_HORIZONS = [30, 90, 365] as const;
export const ACTION_PLAN_WEEKDAYS = [
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
  "sunday",
] as const;

const MAX_NODES = 64;
const MAX_EDGES = 128;
const TOKEN = /^[a-z0-9][a-z0-9._:-]{0,63}$/;
const OPAQUE_ID = /^[A-Za-z0-9_-]{1,128}$/;
const FORBIDDEN_REQUEST_FIELD_PARTS = [
  "original",
  "originalid",
  "userid",
  "entryid",
  "quote",
  "transcript",
  "evidence",
  "label",
  "title",
  "text",
  "content",
  "audio",
  "media",
  "path",
] as const;

const microHabitSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    title: { type: "string", minLength: 1, maxLength: 96 },
    frequency: { type: "string", enum: ["daily", "custom_days"] },
    customWeekdays: {
      type: "array",
      maxItems: 7,
      uniqueItems: true,
      items: { type: "string", enum: ACTION_PLAN_WEEKDAYS },
    },
    targetNodeId: { type: "string", minLength: 1, maxLength: 128 },
    stackingCue: {
      anyOf: [
        { type: "string", minLength: 1, maxLength: 160 },
        { type: "null" },
      ],
    },
  },
  required: [
    "title",
    "frequency",
    "customWeekdays",
    "targetNodeId",
    "stackingCue",
  ],
} as const;

export const ActionPlanGeneratorResultSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    planTitle: { type: "string", minLength: 1, maxLength: 80 },
    targetOutcome: { type: "string", minLength: 1, maxLength: 240 },
    microHabits: {
      type: "array",
      minItems: 3,
      maxItems: 3,
      items: microHabitSchema,
    },
  },
  required: ["planTitle", "targetOutcome", "microHabits"],
} as const;

export function parseActionPlanGeneratorRequest(
  value: unknown,
): ActionPlanGeneratorRequest {
  rejectForbiddenRequestFields(value);
  const sourceRecord = record(value, "Action plan request");
  const source = sourceRecord.source;

  if (source === "simulation_trajectory") {
    const object = strictRecord(
      value,
      ["source", "nodes", "edges", "aggregateMetrics", "trajectoryData"],
      "Simulation trajectory request",
    );
    const structure = parseStructure(object);
    const trajectoryData = boundedArray(
      object.trajectoryData,
      3,
      3,
      "trajectoryData",
    ).map((item, index) => {
      const point = strictRecord(
        item,
        ["horizonDays", "value"],
        `trajectoryData[${index}]`,
      );
      const horizonDays = integer(
        point.horizonDays,
        30,
        365,
        `trajectoryData[${index}].horizonDays`,
      );
      if (!ACTION_PLAN_HORIZONS.includes(horizonDays as ActionPlanHorizonDays)) {
        throw new Error(`trajectoryData[${index}].horizonDays is invalid.`);
      }
      return {
        horizonDays: horizonDays as ActionPlanHorizonDays,
        value: number(point.value, -1, 1, `trajectoryData[${index}].value`),
      };
    });
    if (
      trajectoryData.some(
        (point, index) => point.horizonDays !== ACTION_PLAN_HORIZONS[index],
      )
    ) {
      throw new Error(
        "trajectoryData horizons must be exactly 30, 90, and 365 in order.",
      );
    }
    return { source, ...structure, trajectoryData };
  }

  if (source === "semantic_cluster") {
    const object = strictRecord(
      value,
      ["source", "nodes", "edges", "aggregateMetrics", "clusterData"],
      "Semantic cluster request",
    );
    const structure = parseStructure(object);
    const cluster = strictRecord(
      object.clusterData,
      ["categoryToken", "cohesion", "activity"],
      "clusterData",
    );
    return {
      source,
      ...structure,
      clusterData: {
        categoryToken: token(cluster.categoryToken, "clusterData.categoryToken"),
        cohesion: number(cluster.cohesion, 0, 1, "clusterData.cohesion"),
        activity: number(cluster.activity, 0, 1, "clusterData.activity"),
      },
    };
  }

  throw new Error(
    "source must be simulation_trajectory or semantic_cluster.",
  );
}

export function parseActionPlanGeneratorResult(
  value: unknown,
  request: ActionPlanGeneratorRequest,
): ActionPlanGeneratorResult {
  const object = strictRecord(
    value,
    ["planTitle", "targetOutcome", "microHabits"],
    "Action plan result",
  );
  const allowedNodeIds = new Set(request.nodes.map((node) => node.id));
  const microHabits = boundedArray(
    object.microHabits,
    3,
    3,
    "microHabits",
  ).map((habit, index) =>
    parseMicroHabit(habit, index, allowedNodeIds),
  ) as ActionPlanGeneratorResult["microHabits"];

  return {
    planTitle: boundedString(object.planTitle, 80, "planTitle"),
    targetOutcome: boundedString(
      object.targetOutcome,
      240,
      "targetOutcome",
    ),
    microHabits,
  };
}

function parseStructure(object: Record<string, unknown>): {
  nodes: ActionPlanNode[];
  edges: ActionPlanEdge[];
  aggregateMetrics: ActionPlanAggregateMetric[];
} {
  const nodes = boundedArray(object.nodes, 1, MAX_NODES, "nodes").map(
    (item, index) => {
      const node = strictRecord(
        item,
        ["id", "typeToken", "weight"],
        `nodes[${index}]`,
      );
      return {
        id: opaqueId(node.id, `nodes[${index}].id`),
        typeToken: token(node.typeToken, `nodes[${index}].typeToken`),
        weight: number(node.weight, 0, 1, `nodes[${index}].weight`),
      };
    },
  );
  ensureUnique(nodes.map((node) => node.id), "Node IDs");
  const nodeIds = new Set(nodes.map((node) => node.id));

  const edges = boundedArray(object.edges, 0, MAX_EDGES, "edges").map(
    (item, index) => {
      const edge = strictRecord(
        item,
        ["id", "sourceNodeId", "targetNodeId", "typeToken", "weight"],
        `edges[${index}]`,
      );
      const sourceNodeId = opaqueId(
        edge.sourceNodeId,
        `edges[${index}].sourceNodeId`,
      );
      const targetNodeId = opaqueId(
        edge.targetNodeId,
        `edges[${index}].targetNodeId`,
      );
      if (!nodeIds.has(sourceNodeId) || !nodeIds.has(targetNodeId)) {
        throw new Error(`edges[${index}] references an unknown node ID.`);
      }
      return {
        id: opaqueId(edge.id, `edges[${index}].id`),
        sourceNodeId,
        targetNodeId,
        typeToken: token(edge.typeToken, `edges[${index}].typeToken`),
        weight: number(edge.weight, 0, 1, `edges[${index}].weight`),
      };
    },
  );
  ensureUnique(edges.map((edge) => edge.id), "Edge IDs");
  const allIds = [...nodeIds, ...edges.map((edge) => edge.id)];
  ensureUnique(allIds, "Node and edge IDs");

  const aggregateMetrics = boundedArray(
    object.aggregateMetrics,
    1,
    32,
    "aggregateMetrics",
  ).map((item, index) => {
    const metric = strictRecord(
      item,
      ["metricToken", "value"],
      `aggregateMetrics[${index}]`,
    );
    return {
      metricToken: token(
        metric.metricToken,
        `aggregateMetrics[${index}].metricToken`,
      ),
      value: number(
        metric.value,
        -1_000_000,
        1_000_000,
        `aggregateMetrics[${index}].value`,
      ),
    };
  });
  ensureUnique(
    aggregateMetrics.map((metric) => metric.metricToken),
    "Aggregate metric tokens",
  );

  return { nodes, edges, aggregateMetrics };
}

function parseMicroHabit(
  value: unknown,
  index: number,
  allowedNodeIds: ReadonlySet<string>,
): ActionPlanMicroHabit {
  const label = `microHabits[${index}]`;
  const object = strictRecord(
    value,
    ["title", "frequency", "customWeekdays", "targetNodeId", "stackingCue"],
    label,
  );
  if (object.frequency !== "daily" && object.frequency !== "custom_days") {
    throw new Error(`${label}.frequency is invalid.`);
  }
  const customWeekdays = boundedArray(
    object.customWeekdays,
    0,
    7,
    `${label}.customWeekdays`,
  ).map((day, dayIndex) => {
    if (!ACTION_PLAN_WEEKDAYS.includes(day as ActionPlanWeekday)) {
      throw new Error(`${label}.customWeekdays[${dayIndex}] is invalid.`);
    }
    return day as ActionPlanWeekday;
  });
  ensureUnique(customWeekdays, `${label}.customWeekdays`);
  if (
    (object.frequency === "daily" && customWeekdays.length !== 0) ||
    (object.frequency === "custom_days" && customWeekdays.length === 0)
  ) {
    throw new Error(
      `${label}.customWeekdays must be empty for daily and populated for custom_days.`,
    );
  }
  const targetNodeId = opaqueId(object.targetNodeId, `${label}.targetNodeId`);
  if (!allowedNodeIds.has(targetNodeId)) {
    throw new Error(`${label}.targetNodeId is not a request node ID.`);
  }
  return {
    title: boundedString(object.title, 96, `${label}.title`),
    frequency: object.frequency,
    customWeekdays,
    targetNodeId,
    stackingCue:
      object.stackingCue === null
        ? null
        : boundedString(object.stackingCue, 160, `${label}.stackingCue`),
  };
}

function rejectForbiddenRequestFields(value: unknown): void {
  if (Array.isArray(value)) {
    value.forEach(rejectForbiddenRequestFields);
    return;
  }
  if (!value || typeof value !== "object") return;
  for (const [key, child] of Object.entries(value as Record<string, unknown>)) {
    const normalized = key.replace(/[^a-z0-9]/gi, "").toLowerCase();
    if (
      FORBIDDEN_REQUEST_FIELD_PARTS.some((part) => normalized.includes(part))
    ) {
      throw new Error(`Forbidden personal-content field: ${key}.`);
    }
    rejectForbiddenRequestFields(child);
  }
}

function record(value: unknown, label: string): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`${label} must be an object.`);
  }
  return value as Record<string, unknown>;
}

function strictRecord(
  value: unknown,
  allowedKeys: readonly string[],
  label: string,
): Record<string, unknown> {
  const object = record(value, label);
  if (Object.keys(object).some((key) => !allowedKeys.includes(key))) {
    throw new Error(`${label} contains unknown fields.`);
  }
  if (allowedKeys.some((key) => !(key in object))) {
    throw new Error(`${label} is missing required fields.`);
  }
  return object;
}

function boundedArray(
  value: unknown,
  min: number,
  max: number,
  label: string,
): unknown[] {
  if (!Array.isArray(value) || value.length < min || value.length > max) {
    throw new Error(`${label} must contain between ${min} and ${max} items.`);
  }
  return value;
}

function token(value: unknown, label: string): string {
  if (typeof value !== "string" || !TOKEN.test(value)) {
    throw new Error(`${label} must be a lowercase structural token.`);
  }
  return value;
}

function opaqueId(value: unknown, label: string): string {
  if (typeof value !== "string" || !OPAQUE_ID.test(value)) {
    throw new Error(`${label} must be a request-scoped opaque identifier.`);
  }
  return value;
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

function number(
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

function integer(
  value: unknown,
  min: number,
  max: number,
  label: string,
): number {
  const result = number(value, min, max, label);
  if (!Number.isInteger(result)) throw new Error(`${label} must be an integer.`);
  return result;
}

function ensureUnique(values: readonly string[], label: string): void {
  if (new Set(values).size !== values.length) {
    throw new Error(`${label} must be unique.`);
  }
}
