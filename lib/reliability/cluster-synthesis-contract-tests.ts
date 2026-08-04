import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

import {
  ClusterSynthesisResultSchema,
  MAX_CLUSTER_SYNTHESIS_NODES,
  parseClusterSynthesisRequest,
  parseClusterSynthesisResult,
} from "@/lib/cluster-synthesis/cluster-synthesis-contract";

const validRequest = {
  clusterId: "cluster_01",
  category: "recurring-theme",
  candidateTitle: "Creative routines",
  nodes: [
    {
      anonymousId: "node_01",
      type: "theme",
      label: "creative practice",
      degree: 4,
      activityWeight: 0.72,
    },
    {
      anonymousId: "node_02",
      type: "goal",
      label: "consistent routine",
      degree: 3,
      activityWeight: 0.61,
    },
  ],
  edgeMetrics: {
    edgeCount: 5,
    density: 0.42,
    averageWeight: 0.68,
  },
  vectorMetrics: {
    cohesion: 0.79,
    separation: 0.55,
    centroidMagnitude: 1.4,
  },
  velocityMetrics: {
    averageVelocity: 0.08,
    acceleration: -0.01,
    stability: 0.86,
  },
};

export function runClusterSynthesisContractTests(): void {
  const request = parseClusterSynthesisRequest(validRequest);
  assert.equal(request.nodes.length, 2);
  assert.equal(request.edgeMetrics.density, 0.42);

  const result = parseClusterSynthesisResult({
    title: "Creative routines",
    briefSummary:
      "This cluster may reflect a recurring connection between creative practice and consistency.",
    category: "recurring-theme",
    confidenceScore: 0.81,
  });
  assert.equal(result.title, "Creative routines");
  assert.equal(result.confidenceScore, 0.81);
  assert.equal(ClusterSynthesisResultSchema.additionalProperties, false);
  assert.deepEqual(ClusterSynthesisResultSchema.required, [
    "title",
    "briefSummary",
    "category",
    "confidenceScore",
  ]);

  assert.throws(
    () => parseClusterSynthesisResult({ ...result, diagnosis: "condition" }),
    /unknown fields/,
  );
  assert.throws(
    () =>
      parseClusterSynthesisResult({
        ...result,
        confidenceScore: 1.01,
      }),
    /confidenceScore/,
  );
  assert.throws(
    () => parseClusterSynthesisRequest({ ...validRequest, unexpected: true }),
    /unknown fields/,
  );
  assert.throws(
    () =>
      parseClusterSynthesisRequest({
        ...validRequest,
        nodes: [
          ...validRequest.nodes,
          { ...validRequest.nodes[0], anonymousId: "node_01" },
        ],
      }),
    /unique/,
  );
  assert.throws(
    () =>
      parseClusterSynthesisRequest({
        ...validRequest,
        nodes: Array.from(
          { length: MAX_CLUSTER_SYNTHESIS_NODES + 1 },
          (_, index) => ({
            ...validRequest.nodes[0],
            anonymousId: `node_${index}`,
          }),
        ),
      }),
    /nodes/,
  );

  for (const forbidden of [
    { transcript: "raw words" },
    { evidence: ["quote"] },
    { audioUrl: "https://example.invalid/audio" },
    { userId: "user-1" },
    { rawContent: "private content" },
  ]) {
    assert.throws(
      () =>
        parseClusterSynthesisRequest({
          ...validRequest,
          nodes: [{ ...validRequest.nodes[0], ...forbidden }],
        }),
      /Forbidden personal-content field/,
    );
  }

  const route = fs.readFileSync(
    path.join(process.cwd(), "experiments/backend/app/api/cluster-synthesis/route.ts"),
    "utf8",
  );
  const ephemeralResponse = fs.readFileSync(
    path.join(process.cwd(), "lib/privacy/ephemeral-ai-response.ts"),
    "utf8",
  );

  assert.match(route, /export const runtime = "nodejs"/);
  assert.match(route, /export const dynamic = "force-dynamic"/);
  assert.match(route, /export async function GET/);
  assert.match(route, /status: 405/);
  assert.match(route, /isAllowedVoiceSessionOrigin/);
  assert.match(route, /x-vm-client/);
  assert.match(route, /voicememory-mobile/);
  assert.match(route, /MAX_CLUSTER_SYNTHESIS_BODY_BYTES/);
  assert.match(route, /Buffer\.byteLength/);
  assert.match(route, /guardOpenAiRoute\(request, "analyze"/);
  assert.match(route, /store: false/);
  assert.match(route, /type: "json_schema"/);
  assert.match(route, /strict: true/);
  assert.match(route, /ClusterSynthesisResultSchema/);
  assert.match(route, /parseClusterSynthesisResult\(JSON\.parse\(content\)\)/);
  assert.match(route, /meterConfiguredOpenAiChatUsage/);
  assert.match(route, /vendorRequestId/);
  assert.match(route, /ephemeralAiJson/);
  assert.match(route, /gpt-4o-mini/);
  assert.match(route, /VOICEMEMORY_CLUSTER_SYNTHESIS_MODEL/);
  assert.match(route, /observational/);
  assert.match(route, /diagnoses/);
  assert.match(ephemeralResponse, /private, no-store/);
  assert.doesNotMatch(route, /RevenueCat|requireRevenueCatEntitlement/);
  assert.doesNotMatch(
    route,
    /console\.(?:log|info|debug|warn|error)\([^)]*(?:rawBody|body|nodes|content)/s,
  );
}
