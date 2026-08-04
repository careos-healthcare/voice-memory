import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

import {
  LIFE_SIMULATOR_HORIZONS,
  LifeSimulatorResultSchema,
  parseLifeSimulatorRequest,
  parseLifeSimulatorResult,
} from "@/lib/life-simulator/life-simulator-contract";

const validRequest = {
  target: {
    categoryToken: "work-pattern",
    typeToken: "continuity",
  },
  nodes: [
    { id: "n_01", typeToken: "pattern", weight: 0.8 },
    { id: "n_02", typeToken: "constraint", weight: 0.55 },
  ],
  edges: [
    {
      id: "e_01",
      sourceNodeId: "n_01",
      targetNodeId: "n_02",
      typeToken: "associated-with",
      weight: 0.64,
    },
  ],
  aggregateTopology: {
    nodeCount: 2,
    edgeCount: 1,
    density: 0.5,
    componentCount: 1,
  },
  historicalDeltas: [
    {
      windowDays: 90,
      affectedId: "n_01",
      metricToken: "frequency",
      delta: 0.24,
    },
  ],
  externalCorrelationSummaries: [
    {
      signalToken: "calendar-load",
      direction: "positive",
      strength: 0.52,
      sampleSize: 18,
      lagDays: 2,
    },
  ],
  citations: [
    {
      handle: "cit_A7p2",
      signalToken: "frequency-delta",
      direction: "positive",
      strength: 0.78,
      recencyDays: 4,
    },
    {
      handle: "cit_Q9x1",
      signalToken: "topology-density",
      direction: "neutral",
      strength: 0.41,
      recencyDays: 16,
    },
  ],
} as const;

export function runLifeSimulatorContractTests(): void {
  const request = parseLifeSimulatorRequest(validRequest);
  assert.equal(request.aggregateTopology.nodeCount, request.nodes.length);
  assert.deepEqual(LIFE_SIMULATOR_HORIZONS, [30, 90, 365]);

  const result = validResult();
  const parsed = parseLifeSimulatorResult(result, request);
  assert.deepEqual(
    parsed.continueTrajectory.milestones.map((item) => item.horizonDays),
    [30, 90, 365],
  );
  assert.equal(
    parsed.stopOrPivotTrajectory.milestones[0].stressImpactScore,
    0.36,
  );

  assert.equal(LifeSimulatorResultSchema.additionalProperties, false);
  assert.deepEqual(LifeSimulatorResultSchema.required, [
    "continueTrajectory",
    "stopOrPivotTrajectory",
  ]);

  assert.throws(
    () =>
      parseLifeSimulatorRequest({
        ...validRequest,
        userId: "user-1",
      }),
    /Forbidden personal-content field/,
  );
  for (const forbidden of [
    { entryId: "entry-1" },
    { quote: "private words" },
    { transcript: "private words" },
    { label: "descriptive label" },
    { evidenceText: "private evidence" },
    { audioPath: "/private/file.m4a" },
    { mediaUrl: "https://example.invalid/private" },
  ]) {
    assert.throws(
      () =>
        parseLifeSimulatorRequest({
          ...validRequest,
          citations: [{ ...validRequest.citations[0], ...forbidden }],
        }),
      /Forbidden personal-content field/,
    );
  }
  assert.throws(
    () =>
      parseLifeSimulatorRequest({
        ...validRequest,
        target: { ...validRequest.target, categoryToken: "Free text sentence" },
      }),
    /structural token/,
  );
  assert.throws(
    () =>
      parseLifeSimulatorRequest({
        ...validRequest,
        aggregateTopology: {
          ...validRequest.aggregateTopology,
          nodeCount: 1,
        },
      }),
    /counts must match/,
  );
  assert.throws(
    () =>
      parseLifeSimulatorRequest({
        ...validRequest,
        edges: [
          {
            ...validRequest.edges[0],
            targetNodeId: "invented_node",
          },
        ],
      }),
    /unknown node ID/,
  );

  assert.throws(
    () =>
      parseLifeSimulatorResult(
        {
          ...result,
          continueTrajectory: {
            ...result.continueTrajectory,
            milestones: [
              result.continueTrajectory.milestones[1],
              result.continueTrajectory.milestones[0],
              result.continueTrajectory.milestones[2],
            ],
          },
        },
        request,
      ),
    /exactly 30, 90, and 365/,
  );
  assert.throws(
    () =>
      parseLifeSimulatorResult(
        {
          ...result,
          continueTrajectory: {
            ...result.continueTrajectory,
            milestones: [
              {
                ...result.continueTrajectory.milestones[0],
                affectedIds: ["invented_node"],
              },
              ...result.continueTrajectory.milestones.slice(1),
            ],
          },
        },
        request,
      ),
    /ID not present/,
  );
  assert.throws(
    () =>
      parseLifeSimulatorResult(
        {
          ...result,
          stopOrPivotTrajectory: {
            ...result.stopOrPivotTrajectory,
            milestones: [
              {
                ...result.stopOrPivotTrajectory.milestones[0],
                citationHandles: ["invented_handle"],
              },
              ...result.stopOrPivotTrajectory.milestones.slice(1),
            ],
          },
        },
        request,
      ),
    /handle not present/,
  );
  assert.throws(
    () =>
      parseLifeSimulatorResult(
        {
          ...result,
          continueTrajectory: {
            ...result.continueTrajectory,
            milestones: [
              {
                ...result.continueTrajectory.milestones[0],
                projectedConfidence: 1.01,
              },
              ...result.continueTrajectory.milestones.slice(1),
            ],
          },
        },
        request,
      ),
    /projectedConfidence/,
  );
  assert.throws(
    () =>
      parseLifeSimulatorResult(
        { ...result, diagnosticSummary: "condition" },
        request,
      ),
    /unknown fields/,
  );

  const route = fs.readFileSync(
    path.join(process.cwd(), "experiments/backend/app/api/life-simulator/route.ts"),
    "utf8",
  );
  assert.match(route, /export const runtime = "nodejs"/);
  assert.match(route, /export const dynamic = "force-dynamic"/);
  assert.match(route, /32 \* 1024/);
  assert.match(route, /isAllowedVoiceSessionOrigin/);
  assert.match(route, /voicememory-mobile/);
  assert.match(route, /guardOpenAiRoute\(request, "analyze"/);
  assert.match(route, /type: "json_schema"/);
  assert.match(route, /strict: true/);
  assert.match(route, /store: false/);
  assert.match(route, /VOICEMEMORY_LIFE_SIMULATOR_MODEL/);
  assert.match(route, /gpt-4o-mini/);
  assert.match(route, /meterConfiguredOpenAiChatUsage/);
  assert.match(route, /vendorRequestId/);
  assert.match(route, /observational counterfactual/);
  assert.match(route, /not a prediction, diagnosis/);
  assert.match(route, /ephemeralGuardResponse/);
  assert.doesNotMatch(
    route,
    /console\.(?:log|info|debug|warn|error)\([^)]*(?:rawBody|body|content|nodes|edges)/s,
  );
}

function validResult() {
  return {
    continueTrajectory: {
      summary:
        "If the pattern continues, the supplied structure suggests that its influence may broaden, though the aggregate signals remain uncertain.",
      milestones: [
        milestone(30, 0.72, 0.52, 0.58, ["n_01"], ["cit_A7p2"]),
        milestone(90, 0.64, 0.6, 0.5, ["n_01", "e_01"], [
          "cit_A7p2",
          "cit_Q9x1",
        ]),
        milestone(365, 0.42, 0.68, 0.41, ["n_01", "n_02", "e_01"], [
          "cit_Q9x1",
        ]),
      ],
    },
    stopOrPivotTrajectory: {
      summary:
        "If the pattern stops or pivots, structural pressure may ease while adjacent nodes could temporarily remain active.",
      milestones: [
        milestone(30, 0.7, 0.36, 0.66, ["n_01"], ["cit_A7p2"]),
        milestone(90, 0.6, 0.29, 0.71, ["n_01", "n_02"], ["cit_Q9x1"]),
        milestone(365, 0.38, 0.25, 0.73, ["e_01"], ["cit_Q9x1"]),
      ],
    },
  };
}

function milestone(
  horizonDays: number,
  projectedConfidence: number,
  stressImpactScore: number,
  healthCorrelation: number | null,
  affectedIds: string[],
  citationHandles: string[],
) {
  return {
    horizonDays,
    narrativeSummary: `At ${horizonDays} days, the anonymized structure may shift within the indicated range.`,
    projectedConfidence,
    stressImpactScore,
    healthCorrelation,
    affectedIds,
    citationHandles,
  };
}
