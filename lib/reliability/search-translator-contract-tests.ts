import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

import {
  normalizeSearchIntentTimeframe,
  parseSearchIntent,
  SearchIntentSchema,
} from "@/lib/search-translator/search-intent-contract";

export async function runSearchTranslatorContractTests(): Promise<void> {
  const now = new Date("2026-07-27T12:00:00.000Z");
  const summer = normalizeSearchIntentTimeframe(
    parseSearchIntent({
      semantic_query: "overwhelmed project deadlines",
      timeframe: {
        start: "2025-05-31T00:00:00.000Z",
        end: "2025-08-31T00:00:00.000Z",
      },
      node_types: ["emotion"],
      required_entities: ["project deadlines"],
    }),
    "Show me when I felt overwhelmed by project deadlines last summer",
    now,
  );
  assert.deepEqual(summer.timeframe, {
    start: "2025-06-01T00:00:00.000Z",
    end: "2025-09-01T00:00:00.000Z",
  });

  const twoWeeks = normalizeSearchIntentTimeframe(
    parseSearchIntent({
      semantic_query: "relationship conversations",
      timeframe: null,
      node_types: ["person"],
      required_entities: [],
    }),
    "relationship conversations two weeks ago",
    now,
  );
  assert.deepEqual(twoWeeks.timeframe, {
    start: "2026-07-13T00:00:00.000Z",
    end: "2026-07-27T00:00:00.000Z",
  });

  assert.equal(SearchIntentSchema.additionalProperties, false);
  assert.throws(() =>
    parseSearchIntent({
      semantic_query: "query",
      timeframe: null,
      node_types: ["diagnosis"],
      required_entities: [],
    }),
  );

  const route = fs.readFileSync(
    path.join(process.cwd(), "experiments/backend/app/api/search-translator/route.ts"),
    "utf8",
  );
  assert.match(route, /type: "json_schema"/);
  assert.match(route, /strict: true/);
  assert.match(route, /guardOpenAiRoute\(request, "analyze"/);
  assert.match(route, /isAllowedVoiceSessionOrigin/);
  assert.match(route, /ephemeralAiJson/);
  assert.doesNotMatch(route, /journalStore|LocalSemanticStore|transcript:/);
}
