export const SPATIAL_NEXUS_SCHEMA = "archive-spatial-nexus";
export const SPATIAL_NEXUS_VERSION = 1;
export const MAX_SPATIAL_SNAPSHOT_BYTES = 2 * 1024 * 1024;
export const MAX_SPATIAL_NODES = 1024;
export const MAX_SPATIAL_EDGES = 4096;

export type SpatialNexusNode = {
  id: string;
  label: string;
  type: string;
  position: { x: number; y: number; z: number };
  radius: number;
  valence: number;
  horizon: boolean;
};

export type SpatialNexusEdge = {
  source: string;
  target: string;
  weight: number;
};

export type SpatialNexusSnapshot = {
  schema: typeof SPATIAL_NEXUS_SCHEMA;
  version: typeof SPATIAL_NEXUS_VERSION;
  preset: "neuralVoid" | "cyberneticGrid" | "organicSanctuary";
  nodes: SpatialNexusNode[];
  edges: SpatialNexusEdge[];
};

function finite(value: unknown, minimum: number, maximum: number): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new Error("Spatial snapshot contains a non-finite number.");
  }
  if (value < minimum || value > maximum) {
    throw new Error("Spatial snapshot number is outside allowed bounds.");
  }
  return value;
}

function text(value: unknown, maxLength: number): string {
  if (
    typeof value !== "string" ||
    value.length === 0 ||
    value.length > maxLength
  ) {
    throw new Error("Spatial snapshot contains invalid text.");
  }
  return value;
}

export function parseSpatialNexusSnapshot(
  input: unknown,
): SpatialNexusSnapshot {
  if (typeof input !== "object" || input === null) {
    throw new Error("Spatial snapshot must be an object.");
  }
  const source = input as Record<string, unknown>;
  if (
    source.schema !== SPATIAL_NEXUS_SCHEMA ||
    source.version !== SPATIAL_NEXUS_VERSION
  ) {
    throw new Error("Unsupported Spatial Nexus snapshot.");
  }
  if (
    source.preset !== "neuralVoid" &&
    source.preset !== "cyberneticGrid" &&
    source.preset !== "organicSanctuary"
  ) {
    throw new Error("Unknown Spatial Nexus environment.");
  }
  if (
    !Array.isArray(source.nodes) ||
    source.nodes.length > MAX_SPATIAL_NODES ||
    !Array.isArray(source.edges) ||
    source.edges.length > MAX_SPATIAL_EDGES
  ) {
    throw new Error("Spatial snapshot exceeds local rendering bounds.");
  }
  const ids = new Set<string>();
  const nodes = source.nodes.map((raw): SpatialNexusNode => {
    if (typeof raw !== "object" || raw === null) {
      throw new Error("Invalid spatial node.");
    }
    const node = raw as Record<string, unknown>;
    const position = node.position;
    if (typeof position !== "object" || position === null) {
      throw new Error("Invalid spatial node position.");
    }
    const coordinates = position as Record<string, unknown>;
    const id = text(node.id, 64);
    if (ids.has(id)) throw new Error("Duplicate spatial node.");
    ids.add(id);
    return {
      id,
      label: text(node.label, 80),
      type: text(node.type, 40),
      position: {
        x: finite(coordinates.x, -100, 100),
        y: finite(coordinates.y, -100, 100),
        z: finite(coordinates.z, -100, 100),
      },
      radius: finite(node.radius, 0.01, 5),
      valence: finite(node.valence, -1, 1),
      horizon: node.horizon === true,
    };
  });
  const edges = source.edges.map((raw): SpatialNexusEdge => {
    if (typeof raw !== "object" || raw === null) {
      throw new Error("Invalid spatial edge.");
    }
    const edge = raw as Record<string, unknown>;
    const sourceId = text(edge.source, 64);
    const targetId = text(edge.target, 64);
    if (!ids.has(sourceId) || !ids.has(targetId)) {
      throw new Error("Spatial edge references an unknown node.");
    }
    return {
      source: sourceId,
      target: targetId,
      weight: finite(edge.weight, 0, 1),
    };
  });
  return {
    schema: SPATIAL_NEXUS_SCHEMA,
    version: SPATIAL_NEXUS_VERSION,
    preset: source.preset,
    nodes,
    edges,
  };
}
