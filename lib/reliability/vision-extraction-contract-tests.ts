import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

import {
  parseVisionExtraction,
  VisionExtractionSchema,
} from "@/lib/vision-extraction/vision-extraction-contract";

export async function runVisionExtractionContractTests(): Promise<void> {
  const extraction = parseVisionExtraction({
    sceneSummary: "A mug sits beside a closed notebook on a desk.",
    visibleText: ["NOTES"],
    entities: [
      { kind: "object", label: "mug", confidence: 0.98 },
      { kind: "object", label: "notebook", confidence: 0.95 },
      { kind: "text", label: "NOTES", confidence: 0.91 },
    ],
    relationships: [
      {
        source: "mug",
        target: "notebook",
        relationship: "beside",
        confidence: 0.9,
      },
    ],
  });
  assert.equal(extraction.entities[0]?.kind, "object");
  assert.equal(extraction.relationships[0]?.confidence, 0.9);
  assert.equal(VisionExtractionSchema.additionalProperties, false);
  assert.deepEqual(VisionExtractionSchema.required, [
    "sceneSummary",
    "visibleText",
    "entities",
    "relationships",
  ]);

  assert.throws(() =>
    parseVisionExtraction({
      ...extraction,
      identity: "A named person",
    }),
  );
  assert.throws(() =>
    parseVisionExtraction({
      ...extraction,
      entities: [{ kind: "diagnosis", label: "condition", confidence: 0.8 }],
      relationships: [],
    }),
  );
  assert.throws(() =>
    parseVisionExtraction({
      ...extraction,
      entities: [{ kind: "place", label: "office", confidence: 1.1 }],
      relationships: [],
    }),
  );
  assert.throws(() =>
    parseVisionExtraction({
      ...extraction,
      relationships: [
        {
          source: "unknown",
          target: "notebook",
          relationship: "beside",
          confidence: 0.8,
        },
      ],
    }),
  );

  const route = fs.readFileSync(
    path.join(process.cwd(), "experiments/backend/app/api/vision-extraction/route.ts"),
    "utf8",
  );
  assert.match(route, /export const runtime = "nodejs"/);
  assert.match(route, /export const dynamic = "force-dynamic"/);
  assert.match(route, /export async function GET/);
  assert.match(route, /status: 405/);
  assert.match(route, /formData\.get\("image"\)/);
  assert.match(route, /4 \* 1024 \* 1024/);
  assert.match(route, /image\/jpeg/);
  assert.match(route, /image\/png/);
  assert.match(route, /image\/webp/);
  assert.match(route, /isAllowedVoiceSessionOrigin/);
  assert.match(route, /guardOpenAiRoute\(request, "analyze"\)/);
  assert.match(route, /model: MODEL/);
  assert.match(route, /const MODEL = "gpt-4o-mini"/);
  assert.match(route, /store: false/);
  assert.match(route, /type: "json_schema"/);
  assert.match(route, /strict: true/);
  assert.match(route, /data:\$\{image\.type\};base64/);
  assert.match(route, /meterBestEffort/);
  assert.match(route, /meterConfiguredOpenAiChatUsage/);
  assert.match(route, /ephemeralAiJson/);
  assert.match(route, /Do not identify/);
  assert.match(route, /diagnoses/);
  assert.doesNotMatch(route, /console\.(?:log|error)\([^)]*(?:imageBytes|dataUrl|base64)/s);
}
