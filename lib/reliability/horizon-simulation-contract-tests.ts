import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

import {
  HORIZON_PRIVACY_HEADERS,
  parseHorizonSimulationRequest,
  parseHorizonSimulationResult,
} from "@/backend/src/api/horizon-simulation/contracts";
import { HorizonSimulationResultSchema } from "@/backend/src/api/horizon-simulation/schema";
import {
  GET,
  MAX_HORIZON_SIMULATION_BODY_BYTES,
} from "@/experiments/backend/app/api/horizon-simulation/route";

const request = {
  divergence: { typeToken: "decision", confidence: 0.8, degree: 4 },
  clusters: [
    {
      token: "c_01",
      category: "project",
      size: 8,
      velocity: 0.6,
      confidence: 0.75,
    },
  ],
  parameters: {
    resourceCommitment: 0.5,
    changeTolerance: 0.7,
    timeCommitment: 0.6,
    uncertaintyTolerance: 0.4,
  },
};

export async function runHorizonSimulationContractTests(): Promise<void> {
  assert.equal(parseHorizonSimulationRequest(request).clusters.length, 1);
  assert.throws(
    () =>
      parseHorizonSimulationRequest({
        ...request,
        journalText: "private words",
      }),
    /Private field|fields are invalid/,
  );
  const output = parseHorizonSimulationResult({
    projections: [1, 3, 5].map((year) => ({
      id: `future_${year}`,
      year,
      label: `Conditional year ${year} outcome`,
      nodeType: "outcome",
      probability: 0.55,
      vectors: {
        financial: 0.4,
        emotional: 0.5,
        career: 0.6,
        cognitiveLoad: 0.4,
        alignment: 0.7,
        reward: 0.65,
      },
      rippleEffects: ["May alter adjacent aggregate trajectories."],
    })),
  });
  assert.deepEqual(
    output.projections.map((item) => item.year),
    [1, 3, 5],
  );
  assert.equal(HorizonSimulationResultSchema.additionalProperties, false);

  const response = await GET();
  assert.equal(response.status, 405);
  assert.equal(
    response.headers.get("x-ai-data-retention"),
    HORIZON_PRIVACY_HEADERS["X-AI-Data-Retention"],
  );
  assert.equal(response.headers.get("x-openai-store"), "false");
  assert.match(response.headers.get("cache-control") ?? "", /no-store/);
  const discovery = await response.json();
  assert.equal(discovery.maxBodyBytes, MAX_HORIZON_SIMULATION_BODY_BYTES);

  const routeSource = await readFile(
    new URL("../../experiments/backend/app/api/horizon-simulation/route.ts", import.meta.url),
    "utf8",
  );
  assert.match(routeSource, /store:\s*false/);
}
