import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

const ROOT = process.cwd();
const ROUTE_PATH = path.join(ROOT, "app/api/transcribe/route.ts");

function readRouteSource(): string {
  return fs.readFileSync(ROUTE_PATH, "utf8");
}

export async function runTranscribeRouteTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];

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
    assert.match(source, /NextResponse\.json/);
    assert.match(source, /formData\.get\("audio"\)/);
    assert.match(source, /guardOpenAiRoute\(request, "transcribe"/);
    assert.match(source, /openai\.audio\.transcriptions\.create/);
  });

  await check("GET handler returns JSON 405 route info", () => {
    const source = readRouteSource();
    assert.match(source, /METHOD_NOT_ALLOWED/);
    assert.match(source, /multipartField: "audio"/);
    assert.match(source, /captureTokenHeader: "x-vm-capture-token"/);
  });

  await check("POST missing audio returns JSON AUDIO_REQUIRED", () => {
    const source = readRouteSource();
    assert.match(source, /Audio file is required/);
    assert.match(source, /AUDIO_REQUIRED/);
    assert.match(source, /status: 400/);
  });

  await check("POST errors return JSON with code", () => {
    const source = readRouteSource();
    assert.match(source, /safeOpenAiRouteError\("transcribe"/);
    assert.match(source, /NextResponse\.json\(\s*\{\s*error: safe\.message, code: safe\.code \}/);
  });

  return { failures };
}
