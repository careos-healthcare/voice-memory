import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

import {
  buildLiveAudioInputMessage,
  buildLiveAudioStreamEndMessage,
  buildLiveSetupMessage,
  normalizeLiveModelResource,
  parseLiveClientMessage,
  parseLiveServerMessage,
} from "@/lib/live-audio/protocol";

const FIXTURES_DIR = path.join(process.cwd(), "packages/shared/lib/live-audio/fixtures");

function readFixture(name: string): unknown {
  return JSON.parse(fs.readFileSync(path.join(FIXTURES_DIR, name), "utf8"));
}

export async function runLiveAudioProtocolTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];

  function check(name: string, fn: () => void): void {
    try {
      fn();
    } catch (error) {
      failures.push(`${name}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  check("setup frame matches fixture and current model resource", () => {
    const setup = buildLiveSetupMessage();
    const fixture = readFixture("setup-client.json") as ReturnType<typeof buildLiveSetupMessage>;
    assert.deepEqual(setup, fixture);
    assert.match(setup.setup.model, /^models\//);
    assert.deepEqual(setup.setup.generationConfig.responseModalities, ["AUDIO"]);
  });

  check("normalizeLiveModelResource prefixes bare model ids", () => {
    assert.equal(
      normalizeLiveModelResource("gemini-2.5-flash-native-audio-preview-12-2025"),
      "models/gemini-2.5-flash-native-audio-preview-12-2025",
    );
  });

  check("audio input frame uses audio blob not mediaChunks", () => {
    const frame = buildLiveAudioInputMessage(Buffer.from([1, 2, 3, 4]));
    const fixture = readFixture("audio-input-client.json");
    assert.deepEqual(frame, fixture);
    const validated = parseLiveClientMessage(frame);
    assert.equal(validated.ok, true);
  });

  check("audio stream end frame is valid client message", () => {
    const frame = buildLiveAudioStreamEndMessage();
    const validated = parseLiveClientMessage(frame);
    assert.equal(validated.ok, true);
  });

  check("deprecated mediaChunks client frame is rejected", () => {
    const deprecated = readFixture("deprecated-media-chunks-client.json");
    const validated = parseLiveClientMessage(deprecated);
    assert.equal(validated.ok, false);
    if (!validated.ok) {
      assert.equal(validated.reason, "deprecated_media_chunks");
    }
  });

  check("setupComplete server fixture parses to setup_complete event", () => {
    const events = parseLiveServerMessage(readFixture("setup-complete-server.json"));
    assert.deepEqual(events, [{ type: "setup_complete" }]);
  });

  check("server audio chunk fixture parses to audio_output event", () => {
    const events = parseLiveServerMessage(readFixture("server-audio-chunk.json"));
    assert.equal(events.length, 1);
    assert.equal(events[0]?.type, "audio_output");
    if (events[0]?.type === "audio_output") {
      assert.equal(events[0].pcmBase64, "AQIDBAU=");
      assert.equal(events[0].mimeType, "audio/pcm;rate=24000");
    }
  });

  check("client message must contain exactly one top-level key", () => {
    const validated = parseLiveClientMessage({
      setup: {},
      realtimeInput: {},
    });
    assert.equal(validated.ok, false);
    if (!validated.ok) {
      assert.equal(validated.reason, "client_message_must_have_exactly_one_top_level_key");
    }
  });

  return { failures };
}
