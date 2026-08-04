import assert from "node:assert/strict";
import {
  parseSpatialNexusSnapshot,
  SPATIAL_NEXUS_SCHEMA,
  SPATIAL_NEXUS_VERSION,
} from "@/lib/spatial-nexus/snapshot";

export function runSpatialNexusContractTests() {
  const valid = parseSpatialNexusSnapshot({
    schema: SPATIAL_NEXUS_SCHEMA,
    version: SPATIAL_NEXUS_VERSION,
    preset: "neuralVoid",
    nodes: [
      {
        id: "anonymous-node",
        label: "memory 1",
        type: "memory",
        position: { x: 0, y: 1, z: -2 },
        radius: 0.2,
        valence: 0.4,
        horizon: false,
      },
    ],
    edges: [],
  });
  assert.equal(valid.nodes.length, 1);
  assert.throws(
    () =>
      parseSpatialNexusSnapshot({
        ...valid,
        nodes: [{ ...valid.nodes[0], valence: Number.NaN }],
      }),
    /non-finite/,
  );
  assert.throws(
    () =>
      parseSpatialNexusSnapshot({
        ...valid,
        edges: [{ source: "anonymous-node", target: "missing", weight: 1 }],
      }),
    /unknown node/,
  );
}
