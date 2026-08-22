import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";

import { buildEvidencePacket } from "@/lib/evidence/evidence-pipeline";
import type { EvidencePacket } from "@/lib/evidence/evidence-packet";
import type { EvidenceCandidate } from "@/lib/evidence/evidence-source";
import {
  buildPromptContext,
  composePromptUserContent,
  logPromptContextMetadata,
  type PromptContextInput,
  promptContextFromPacket,
  promptContextMetadata,
} from "@/lib/evidence/prompt-context";
import {
  INFLUENCE_INSTRUCTIONS,
  PROMPT_EVIDENCE_HEADER,
  SOURCE_TYPE_INSTRUCTIONS,
} from "@/lib/evidence/prompt-context-contract";

const NOW = new Date("2026-06-12T12:00:00Z");

function daysAgo(days: number): string {
  return new Date(NOW.getTime() - days * 86_400_000).toISOString();
}

function archive(overrides: Partial<EvidenceCandidate> = {}): EvidenceCandidate {
  return {
    sourceType: "user_archive",
    sourceRef: "entry_a1",
    createdAt: daysAgo(2),
    ...overrides,
  };
}

function packetOf(
  candidates: EvidenceCandidate[],
  memoryScope: "automatic" | "ask" | "thread_only" | "off" = "automatic",
): EvidencePacket {
  return buildEvidencePacket(candidates, { memoryScope, now: NOW }).packet;
}

const ENTRY = { transcript: "Today I kept circling the same decision again." };

export async function runPromptContextContractTests(): Promise<{ failures: string[] }> {
  const failures: string[] = [];

  function check(name: string, fn: () => void): void {
    try {
      fn();
    } catch (error) {
      failures.push(`${name}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  check("prompt context can be built from current entry only", () => {
    const context = buildPromptContext({ currentEntry: ENTRY });
    assert.equal(context.evidence.block, "");
    assert.equal(context.evidence.itemCount, 0);
    assert.equal(context.packet, null);
    assert.equal(composePromptUserContent(context), ENTRY.transcript);
  });

  check("prompt context can be built from an evidence packet", () => {
    const context = promptContextFromPacket(packetOf([archive()]), ENTRY);
    assert.equal(context.evidence.itemCount, 1);
    const content = composePromptUserContent(context);
    assert.ok(content.startsWith(ENTRY.transcript));
    assert.ok(content.includes(PROMPT_EVIDENCE_HEADER));
  });

  check("prompt context rejects raw archive strings and dumps", () => {
    assert.throws(
      () =>
        buildPromptContext({
          currentEntry: ENTRY,
          evidencePacket: "three weeks ago you said you were tired of this job",
        } as unknown as PromptContextInput),
      /must be an evidence packet/,
    );
    assert.throws(
      () =>
        buildPromptContext({
          currentEntry: ENTRY,
          evidencePacket: [{ transcript: "raw archive entry" }],
        } as unknown as PromptContextInput),
      /must be an evidence packet/,
    );
    assert.throws(
      () =>
        buildPromptContext({
          currentEntry: ENTRY,
          archiveEntries: [{ transcript: "raw archive entry" }],
        } as unknown as PromptContextInput),
      /unexpected context field "archiveEntries"/,
    );
    assert.throws(
      () =>
        buildPromptContext({
          currentEntry: ENTRY,
          searchResults: ["loose search result"],
        } as unknown as PromptContextInput),
      /unexpected context field "searchResults"/,
    );
    assert.throws(
      () =>
        buildPromptContext({
          currentEntry: "just a raw transcript string",
        } as unknown as PromptContextInput),
      /currentEntry must be/,
    );
  });

  check("prompt context rejects generated_interpretation as evidence", () => {
    const packet = packetOf([archive()]);
    const tampered = JSON.parse(JSON.stringify(packet)) as EvidencePacket;
    tampered.items[0].source_type = "generated_interpretation";
    assert.throws(
      () => buildPromptContext({ currentEntry: ENTRY, evidencePacket: tampered }),
      /generated text is not evidence/,
    );
  });

  check("blocked evidence is excluded from usable prompt evidence", () => {
    const context = promptContextFromPacket(
      packetOf([archive({ userConfirmed: true })], "off"),
      ENTRY,
    );
    assert.equal(context.evidence.itemCount, 0);
    assert.equal(composePromptUserContent(context), ENTRY.transcript);

    const tampered = JSON.parse(JSON.stringify(packetOf([archive()]))) as EvidencePacket;
    tampered.items[0].influence_level = "blocked";
    assert.throws(
      () => buildPromptContext({ currentEntry: ENTRY, evidencePacket: tampered }),
      /non-admitted influence/,
    );
  });

  check("suppressed evidence is excluded from connection claims", () => {
    const context = promptContextFromPacket(
      packetOf([archive({ treatAsNew: true })]),
      ENTRY,
    );
    assert.equal(context.evidence.itemCount, 0);
    assert.ok(!composePromptUserContent(context).includes(PROMPT_EVIDENCE_HEADER));
    assert.ok(
      INFLUENCE_INSTRUCTIONS.suppress.includes("connection claims"),
      "suppress instruction misses connection-claim rule",
    );
  });

  check("background evidence gets the cautious instruction", () => {
    const context = promptContextFromPacket(
      packetOf([archive({ createdAt: daysAgo(60) })]),
      ENTRY,
    );
    const content = composePromptUserContent(context);
    assert.ok(content.includes("influence=background"));
    assert.ok(content.includes(INFLUENCE_INSTRUCTIONS.background));
    assert.ok(content.includes("mention cautiously"));
  });

  check("compare evidence gets the comparison instruction", () => {
    const context = promptContextFromPacket(packetOf([archive()]), ENTRY);
    const content = composePromptUserContent(context);
    assert.ok(content.includes("influence=compare"));
    assert.ok(content.includes(INFLUENCE_INSTRUCTIONS.compare));
  });

  check("high_authority evidence gets the explicit priority instruction", () => {
    const context = promptContextFromPacket(
      packetOf([archive({ userConfirmed: true })]),
      ENTRY,
    );
    const content = composePromptUserContent(context);
    assert.ok(content.includes("influence=high_authority"));
    assert.ok(content.includes(INFLUENCE_INSTRUCTIONS.high_authority));
    assert.ok(content.includes("user-confirmed"));
  });

  check("source-type instructions are rendered per item", () => {
    const context = promptContextFromPacket(
      packetOf([
        archive(),
        { sourceType: "account_state", sourceRef: "signed_in" },
        {
          sourceType: "web_result",
          createdAt: daysAgo(1),
          web: { domain: "news.example.com", title: "Public article" },
        },
      ]),
      ENTRY,
    );
    const content = composePromptUserContent(context);
    assert.ok(content.includes(SOURCE_TYPE_INSTRUCTIONS.user_archive));
    assert.ok(content.includes(SOURCE_TYPE_INSTRUCTIONS.account_state));
    assert.ok(content.includes(SOURCE_TYPE_INSTRUCTIONS.web_result));
  });

  check("context max evidence items remains capped", () => {
    const candidates = Array.from({ length: 9 }, (_, i) =>
      archive({ sourceRef: `entry_${i}`, createdAt: daysAgo(i) }),
    );
    const context = promptContextFromPacket(packetOf(candidates), ENTRY);
    assert.equal(context.evidence.itemCount, 5);
    assert.equal(promptContextMetadata(context).item_count, 5);
  });

  check("no private text in prompt context logs", () => {
    const lines: string[] = [];
    const context = promptContextFromPacket(
      packetOf([archive({ userConfirmed: true })]),
      { transcript: "I told person@example.com my plans. token=sk_secret cookie=abc" },
    );
    logPromptContextMetadata(context, (line) => lines.push(line));

    assert.equal(lines.length, 1);
    assert.ok(lines[0].startsWith("[ArchiveMe] "));
    for (const banned of [
      "person@example.com",
      "sk_secret",
      "cookie",
      "my plans",
      "circling",
      "transcript",
    ]) {
      assert.ok(!lines[0].includes(banned), `log leaked: ${banned}`);
    }
    const payload = JSON.parse(lines[0].replace("[ArchiveMe] ", "")) as Record<
      string,
      unknown
    >;
    assert.equal(payload.event, "prompt_context");
    assert.equal(payload.item_count, 1);
    const items = payload.items as Array<Record<string, unknown>>;
    assert.deepEqual(Object.keys(items[0]).sort(), [
      "authority_state",
      "influence_level",
      "reason_id",
      "redacted",
      "source_type",
    ]);
    assert.equal(items[0].redacted, true);
  });

  check("metadata carries no emails/cookies/tokens", () => {
    const context = promptContextFromPacket(
      packetOf([
        {
          sourceType: "web_result",
          createdAt: daysAgo(1),
          contentSummary: "reach me at a@b.com, session cookie xyz, token sk_live_1",
          summaryIsSafe: true,
          web: { url: "https://x.example.com?session=abc", title: "t" },
        },
      ]),
      ENTRY,
    );
    const metadata = JSON.stringify(promptContextMetadata(context));
    for (const banned of ["a@b.com", "cookie", "sk_live_1", "session", "http"]) {
      assert.ok(!metadata.includes(banned), `metadata leaked: ${banned}`);
    }
  });

  check("memory off produces no archive evidence in prompt context", () => {
    const context = promptContextFromPacket(
      packetOf(
        [archive(), archive({ sourceRef: "entry_b2", userConfirmed: true })],
        "off",
      ),
      ENTRY,
    );
    assert.equal(context.evidence.itemCount, 0);
    assert.ok(!composePromptUserContent(context).includes("user_archive"));
  });

  check("treat-as-new produces no connection evidence", () => {
    const context = promptContextFromPacket(
      packetOf([archive({ treatAsNew: true, userConfirmed: false })]),
      ENTRY,
    );
    assert.equal(context.evidence.itemCount, 0);
  });

  check("analyze route uses the prompt context contract", () => {
    const source = readFileSync(join(process.cwd(), "apps/api/app/api/analyze/route.ts"), "utf8");
    assert.ok(source.includes("buildPromptContext"), "route skips buildPromptContext");
    assert.ok(
      source.includes("composePromptUserContent"),
      "route composes prompt outside the contract",
    );
    assert.ok(source.includes("buildEvidencePacket"), "route skips evidence pipeline");
    assert.ok(!source.includes("priorContext"), "route accepts loose context");
  });

  check("no VoiceMemory in prompt contract copy", () => {
    const rendered = composePromptUserContent(
      promptContextFromPacket(
        packetOf([archive(), { sourceType: "product_state", sourceRef: "pro_active" }]),
        ENTRY,
      ),
    );
    const sweeps = [
      rendered,
      ...Object.values(INFLUENCE_INSTRUCTIONS),
      ...Object.values(SOURCE_TYPE_INSTRUCTIONS),
      PROMPT_EVIDENCE_HEADER,
    ];
    for (const text of sweeps) {
      assert.ok(!/voicememory/i.test(text), `VoiceMemory in contract copy: ${text}`);
    }
  });

  return { failures };
}
