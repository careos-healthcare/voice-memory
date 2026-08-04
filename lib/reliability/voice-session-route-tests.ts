import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

import { isAllowedVoiceSessionOrigin } from "@/lib/server/allowed-api-origin";

export async function runVoiceSessionRouteTests(): Promise<void> {
  const route = fs.readFileSync(
    path.join(process.cwd(), "experiments/backend/app/api/voice-session/route.ts"),
    "utf8",
  );
  assert.match(route, /export async function GET/);
  assert.match(route, /export async function POST/);
  assert.match(route, /guardOpenAiRoute\(request, "analyze"/);
  assert.match(route, /realtime\.clientSecrets\.create/);
  assert.match(route, /query_memory_graph/);
  assert.match(route, /tracing: null/);
  assert.match(route, /ORIGIN_NOT_ALLOWED/);
  assert.match(route, /ephemeralAiJson/);
  assert.doesNotMatch(route, /process\.env\.OPENAI_API_KEY/);

  const previousAppUrl = process.env.APP_URL;
  const previousAllowed = process.env.VOICEMEMORY_ALLOWED_API_ORIGINS;
  process.env.APP_URL = "https://archive.example";
  process.env.VOICEMEMORY_ALLOWED_API_ORIGINS = "capacitor://localhost";
  try {
    assert.equal(
      isAllowedVoiceSessionOrigin(
        new Request("https://archive.example/api/voice-session", {
          headers: { Origin: "https://archive.example" },
        }),
      ),
      true,
    );
    assert.equal(
      isAllowedVoiceSessionOrigin(
        new Request("https://archive.example/api/voice-session", {
          headers: { Origin: "https://evil.example" },
        }),
      ),
      false,
    );
    assert.equal(
      isAllowedVoiceSessionOrigin(
        new Request("https://archive.example/api/voice-session", {
          headers: { "x-vm-client": "voicememory-mobile" },
        }),
      ),
      true,
    );
    assert.equal(
      isAllowedVoiceSessionOrigin(
        new Request("https://archive.example/api/voice-session"),
      ),
      false,
    );
  } finally {
    process.env.APP_URL = previousAppUrl;
    process.env.VOICEMEMORY_ALLOWED_API_ORIGINS = previousAllowed;
  }
}
