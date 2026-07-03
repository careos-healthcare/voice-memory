import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

import {
  ANALYZE_UNAVAILABLE_MESSAGE,
  analyzeRouteClientError,
  classifyAnalyzeRouteError,
} from "../analyze/analyze-route-failure.ts";

const ROOT = process.cwd();
const ROUTE_PATH = path.join(ROOT, "app/api/analyze/route.ts");

function readRouteSource(): string {
  return fs.readFileSync(ROUTE_PATH, "utf8");
}

export async function runAnalyzeRouteTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];
  const priorNodeEnv = process.env.NODE_ENV;
  const priorOpenAiKey = process.env.OPENAI_API_KEY;

  async function check(name: string, fn: () => void | Promise<void>): Promise<void> {
    try {
      await fn();
    } catch (error) {
      failures.push(`${name}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  await check("route source exports GET and POST handlers", () => {
    const source = readRouteSource();
    assert.match(source, /export async function GET/);
    assert.match(source, /export async function POST/);
    assert.match(source, /guardOpenAiRoute\(request, "analyze"/);
    assert.match(source, /parseReflectionResponse/);
    assert.match(source, /analyzeRouteCatchResponse/);
    assert.match(source, /OPENAI_API_KEY/);
    assert.doesNotMatch(source, /console\.error\("Analysis failed:"/);
  });

  await check("GET handler returns JSON 405 route info", () => {
    const source = readRouteSource();
    assert.match(source, /METHOD_NOT_ALLOWED/);
    assert.match(source, /captureTokenHeader: "x-vm-capture-token"/);
  });

  await check("POST missing transcript returns JSON transcript_required", () => {
    const source = readRouteSource();
    assert.match(source, /transcript_required/);
    assert.match(source, /"Transcript is required"/);
  });

  await check("catch response uses stable production JSON shape", () => {
    const client = analyzeRouteClientError(new Error("model timeout"), {
      openAiKeyPresent: true,
      production: true,
    });
    assert.equal(client.status, 502);
    assert.equal(client.code, "ANALYZE_UNAVAILABLE");
    assert.equal(client.message, ANALYZE_UNAVAILABLE_MESSAGE);
  });

  await check("missing OpenAI key returns 503 missing_openai_key", () => {
    const classified = classifyAnalyzeRouteError(new Error("unexpected"), {
      openAiKeyPresent: false,
    });
    assert.equal(classified.code, "missing_openai_key");
    assert.equal(classified.status, 503);
  });

  await check("classify maps OpenAI 401 to missing_openai_key", () => {
    const classified = classifyAnalyzeRouteError(
      { status: 401, message: "invalid" },
      { openAiKeyPresent: true },
    );
    assert.equal(classified.code, "missing_openai_key");
    assert.equal(classified.status, 503);
  });

  await check("classify maps database failures to service_unavailable", () => {
    const classified = classifyAnalyzeRouteError(
      new Error("DATABASE_URL is not configured."),
      { openAiKeyPresent: true },
    );
    assert.equal(classified.code, "service_unavailable");
    assert.equal(classified.status, 503);
  });

  await check("production client error uses ANALYZE_UNAVAILABLE without leaking SDK text", () => {
    const client = analyzeRouteClientError(
      {
        status: 500,
        message: "Internal server error with user transcript leak",
      },
      { openAiKeyPresent: true, production: true },
    );
    assert.equal(client.code, "ANALYZE_UNAVAILABLE");
    assert.equal(client.message, ANALYZE_UNAVAILABLE_MESSAGE);
    assert.equal(client.status, 502);
    assert.doesNotMatch(client.message, /transcript/i);
  });

  process.env.NODE_ENV = priorNodeEnv;
  process.env.OPENAI_API_KEY = priorOpenAiKey;

  return { failures };
}
